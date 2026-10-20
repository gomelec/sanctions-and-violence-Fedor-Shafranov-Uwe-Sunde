"""
clean_gdelt.py
GDELT 1.0 conflict events: aggregate CAMEO root codes (coerce, assault, fight,
mass violence) to country-year normalized counts and Goldstein-weighted
severity, and attach ISO3 / Gleditsch-Ward codes.

Input : data/raw/gdelt/gdelt_conflict_1_0.csv
        data/scripts/cleaning/gdelt_gw_assignments.csv  (year-specific GW assignments)
Output: data/clean/gdelt/gdelt_cy.csv          (one row per GW state x year)
        data/clean/gdelt/gdelt_crosswalk.csv

Refactored 1:1 from archive/notebooks/create_gdelt_data.ipynb (cells 1, 2, 3, 5).

CHANGED 2026-10-20 (see data/README.md, G9-G12):
  - GDELT reports events by PRESENT-DAY country. Countries that were part of another
    GW state in a given year (e.g. Serbia before 2006, Ukraine before 1991) are now
    assigned to that state using gdelt_gw_assignments.csv, instead of being dropped.
  - Several GDELT countries in one GW state-year are combined: Goldstein sums are added;
    *_norm1000 (events per 1,000 GDELT events) are recomputed as total events of the type
    per 1,000 of all events, i.e. weighted by each unit's TotalEvents.
  - New columns: gdelt_total_events (all GDELT events, the denominator) and
    gdelt_n_units (number of GDELT countries combined).
"""
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
RAW = ROOT / "data" / "raw" / "gdelt"
OUT = ROOT / "data" / "clean" / "gdelt"
OUT.mkdir(parents=True, exist_ok=True)

df = pd.read_csv(RAW / "gdelt_conflict_1_0.csv")
df["Year"] = pd.to_datetime(df["Year"].astype(str), format="%Y")

df.sort_values(by=["Year", "CountryName"], inplace=True)

# drop exact duplicate rows (e.g. Burma/Myanmar same CountryCode, different CountryName)
df = df.drop_duplicates(subset=['Year', 'CountryCode', 'EventCode'])

# clean root descr into snake_case for column naming
root_map = {
    'COERCE': 'coerce',
    'ASSAULT': 'assault',
    'FIGHT': 'fight',
    'USE UNCONVENTIONAL MASS VIOLENCE': 'mass_violence',
}
df['root_clean'] = df['EventRootDescr'].map(root_map)

# Goldstein-weighted severity per event row (event count * intensity score)
df['goldstein_weighted'] = df['SumEvents'] * df['GoldsteinScale']

# 1. Normalized events by violence type, per country-year
by_type = (
    df.groupby(['Year', 'CountryCode', 'CountryName', 'root_clean'])['NormalizedEvents1000']
    .sum()
    .unstack('root_clean')
    .add_suffix('_norm1000')
    .reset_index()
)

# 2. Total normalized violence across all 4 categories, per country-year
total_norm = (
    df.groupby(['Year', 'CountryCode'])['NormalizedEvents1000']
    .sum()
    .reset_index()
    .rename(columns={'NormalizedEvents1000': 'total_violence_norm1000'})
)

# 3. Goldstein-weighted severity, by type
goldstein_by_type = (
    df.groupby(['Year', 'CountryCode', 'root_clean'])['goldstein_weighted']
    .sum()
    .unstack('root_clean')
    .add_suffix('_goldstein')
    .reset_index()
)

# 4. Total Goldstein-weighted severity across all types
goldstein_total = (
    df.groupby(['Year', 'CountryCode'])['goldstein_weighted']
    .sum()
    .reset_index()
    .rename(columns={'goldstein_weighted': 'total_violence_goldstein'})
)

# merge everything into one wide panel
panel = by_type.merge(total_norm, on=['Year', 'CountryCode'])
panel = panel.merge(goldstein_by_type, on=['Year', 'CountryCode'])
panel = panel.merge(goldstein_total, on=['Year', 'CountryCode'])

# flip Goldstein sign so higher = more violent (consistent direction with death counts)
goldstein_cols = [c for c in panel.columns if 'goldstein' in c]
panel[goldstein_cols] = panel[goldstein_cols] * -1

# zero-fill missing category values (NaN here = zero events of that type that year, a true zero)
fill_cols = [c for c in panel.columns if 'norm1000' in c or 'goldstein' in c]
panel[fill_cols] = panel[fill_cols].fillna(0)

print(panel.shape)

# --- country codes -------------------------------------------------------------
# CHANGED 2026-10-20: fixed, hand-checked crosswalk instead of running country_converter
# at every run (results identical; see data/README.md, G6). The crosswalk lists all 258
# GDELT country names with ISO3, GW code, the GW name for checking, and a note for every
# manual decision. A GDELT name missing from the crosswalk stops the script.
cw_all = pd.read_csv(ROOT / "data" / "scripts" / "cleaning" / "gdelt_country_crosswalk.csv", dtype={"gwcode": "Int64"})
unknown = sorted(set(df['CountryName']) - set(cw_all['CountryName']))
if unknown:
    raise ValueError(f"GDELT names not in gdelt_country_crosswalk.csv: {unknown}")

# keep names with a valid ISO3 (territories have no GW code and drop out at the merge)
crosswalk = cw_all.loc[cw_all['iso3c'].notna(), ['CountryName', 'iso3c', 'gwcode']]

panel = panel.merge(crosswalk, on='CountryName', how='inner')

print(panel.shape)
print(panel[['CountryName', 'iso3c', 'gwcode']].drop_duplicates().head(10))

# =====================================================================
# ADDED 2026-10-20: assign to the GW state of the time, combine units
# =====================================================================
total_events = (df.groupby(['Year', 'CountryCode'])['TotalEvents'].first()
                .rename('gdelt_total_events').reset_index())
panel = panel.merge(total_events, on=['Year', 'CountryCode'], how='left')

assign = pd.read_csv(ROOT / "data" / "scripts" / "cleaning" / "gdelt_gw_assignments.csv")
yr = panel['Year'].dt.year
n_assigned = 0
for a in assign.itertuples():
    hit = (panel['CountryName'] == a.gdelt_name) & yr.between(a.year_from, a.year_to)
    if not hit.any():
        raise ValueError(f"assignment matches no GDELT rows: {a}")
    panel.loc[hit, 'gwcode'] = a.gwcode
    n_assigned += int(hit.sum())
print("GDELT country-years re-assigned to the GW state of the time:", n_assigned)

norm_cols = [c for c in panel.columns if c.endswith('_norm1000')]
gold_cols = [c for c in panel.columns if c.endswith('_goldstein')]
key = ['Year', 'gwcode']
panel['gdelt_n_units'] = panel.groupby(key)['CountryName'].transform('size')
single = panel[panel['gdelt_n_units'] == 1].copy()          # unchanged values
multi = panel[panel['gdelt_n_units'] > 1].copy()
if len(multi):
    w = multi['gdelt_total_events']
    for c in norm_cols:
        multi[c] = multi[c] * w                              # back to event counts x 1000
    agg = {c: 'sum' for c in norm_cols + gold_cols + ['gdelt_total_events']}
    agg.update({c: (lambda s: ' + '.join(s.astype(str))) for c in ['CountryCode', 'CountryName', 'iso3c']})
    agg['gdelt_n_units'] = 'first'
    multi = multi.groupby(key, as_index=False).agg(agg)
    for c in norm_cols:
        multi[c] = multi[c] / multi['gdelt_total_events']
    print("GW state-years combining several GDELT countries:", len(multi))
panel = pd.concat([single, multi[single.columns]], ignore_index=True).sort_values(key, ignore_index=True)
assert not panel.duplicated(key).any()

panel.to_csv(OUT / "gdelt_cy.csv", index=False)
crosswalk.to_csv(OUT / "gdelt_crosswalk.csv", index=False)
print("Wrote", OUT / "gdelt_cy.csv", panel.shape)
