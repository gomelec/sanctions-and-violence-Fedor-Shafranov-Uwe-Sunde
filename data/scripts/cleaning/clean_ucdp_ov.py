"""
clean_ucdp_ov.py
UCDP Organized Violence Country-Year dataset (v26.1): fix the Serbia code and
keep the variables used in the project.

Input : data/raw/ucdp_ov/OrganizedViolenceCYDataSet26_1.csv
Output: data/clean/ucdp_ov/ucdp_ov_cy.csv

Refactored 1:1 from archive/notebooks/Create_violence_data.ipynb (cells 1, 6, 8).
Zero-filling and per-capita variables are created after the merge, in
data/scripts/processing/process_sanctions_violence.py.
"""
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
RAW = ROOT / "data" / "raw" / "ucdp_ov"
OUT = ROOT / "data" / "clean" / "ucdp_ov"
OUT.mkdir(parents=True, exist_ok=True)

df = pd.read_csv(RAW / "OrganizedViolenceCYDataSet26_1.csv")
df["year"] = pd.to_datetime(df["year"].astype(str), format="%Y")

# Serbia: UCDP keeps gwcode 345 after 2006, the GW base uses 340
# CHANGED 2026-10-20: from 2006 on (was: from 2007), because the base now has Serbia
# (340) and no Yugoslavia (345) in 2006 (see data/README.md, B10 / U1)
df.loc[(df['country_id']==345) & (df['year'] >= pd.Timestamp('2006-01-01')), 'country_id'] = 340

conflict_vars = [
    # Identifiers
    'country',
    'country_id',
    'year',
    'region',
    'govt_name',

    # Existence flags (any violence occurred, by type)
    'sb_exist',
    'sb_intrastate_exist',
    'sb_interstate_exist',
    'ns_exist',
    'os_exist',

    # Government involvement (relevant to sanctions -> regime repression channel)
    'sb_intrastate_govt_inv_incomp',
    'sb_interstate_govt_inv_incomp',
    'os_govt_inv',
    'os_any_govt_inv',

    # Dyad/actor counts (fragmentation of conflict, separate from intensity)
    'sb_dyad_count',
    'sb_intrastate_dyad_count',
    'sb_interstate_dyad_count',
    'ns_dyad_count',
    'os_dyad_count',

    # Cumulative totals (all violence types combined), by victim type
    'cumulative_total_deaths_parties_in_orgvio',
    'cumulative_total_deaths_civilians_in_orgvio',
    'cumulative_total_deaths_unknown_in_orgvio',
    'cumulative_total_deaths_in_orgvio_best',

    # State-based violence, by victim type
    'sb_deaths_parties',
    'sb_deaths_civilians',
    'sb_deaths_unknown',
    'sb_total_deaths_best',

    # State-based intrastate, by victim type
    'sb_intrastate_deaths_parties',
    'sb_intrastate_deaths_civilians',
    'sb_intrastate_deaths_unknown',
    'sb_intrastate_deaths_best',

    # State-based interstate, by victim type
    'sb_interstate_deaths_parties',
    'sb_interstate_deaths_civilians',
    'sb_interstate_deaths_unknown',
    'sb_interstate_deaths_best',

    # Non-state violence, by victim type
    'ns_deaths_parties',
    'ns_deaths_civilians',
    'ns_deaths_unknown',
    'ns_total_deaths_best',

    # One-sided violence, by perpetrator
    'os_govt_killings_best',
    'os_any_govt_killings_best',
    'os_nsgroup_killings_best',
    'os_killings_unknown',
    'os_total_deaths_best',
]

conflict_to_merge = df[conflict_vars]
conflict_to_merge.to_csv(OUT / "ucdp_ov_cy.csv", index=False)
print("Wrote", OUT / "ucdp_ov_cy.csv", conflict_to_merge.shape)
