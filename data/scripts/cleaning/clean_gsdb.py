"""
clean_gsdb.py
Global Sanctions Data Base (GSDB v4, dyadic): harmonise state codes and
aggregate to country-year counts of sanctions RECEIVED and SENT.

Input : data/raw/gsdb/GSDB_V4_dyadic.dta
        data/clean/base/base.csv   (gwcode-year-iso3c crosswalk, for the *_gw counts)
        data/raw/gsdb/GSDB_V4.csv  (case-level types, for the Yugoslavia attribution)
        data/scripts/cleaning/gsdb_yugoslavia_attribution.csv
Output: data/clean/gsdb/gsdb_received.csv   (country_iso3 x year)
        data/clean/gsdb/gsdb_sent.csv       (country_iso3 x year)
        data/clean/gsdb/gsdb_yugoslavia_attribution_log.csv (every changed dyad, before/after)
        data/clean/gsdb/gsdb_set_aside.csv  (rows kept out of the counts: non-GW entities)
        data/clean/gsdb/gsdb_self_dyads_dropped.csv (sender == target after recoding)

Refactored 1:1 from archive/notebooks/create_sanction_data.ipynb (cells 3 and 6).

Two ways of counting countries (both kept):
  num_sanctioners, num_targets_sanctioned
      ORIGINAL: number of distinct country NAMES in GSDB. Names are not recoded,
      so e.g. Serbia and Montenegro count as 2 before 2006.
  num_sanctioners_gw, num_targets_sanctioned_gw
      ADDED 2026-10-20: number of distinct Gleditsch-Ward states (gwcode). The recoded
      ISO3 code of each sender/target is matched to the gwcode of the state-year
      base, so counts follow the same country definitions as the panel.
      Countries without a GW state that year are not counted (listed in the log).
The merge onto the state-year base now lives in
data/scripts/processing/process_sanctions_violence.py.
"""
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
RAW = ROOT / "data" / "raw" / "gsdb"
OUT = ROOT / "data" / "clean" / "gsdb"
OUT.mkdir(parents=True, exist_ok=True)

df = pd.read_stata(RAW / "GSDB_V4_dyadic.dta")

# integer year (GSDB stores the year as a date like 1993-01-01)
yr = pd.to_datetime(df["year"]).dt.year

iso_cols  = ["sanctioning_state_iso3", "sanctioned_state_iso3"]
name_cols = ["sanctioning_state", "sanctioned_state"]

# snapshot the ORIGINAL codes — the drop/separate masks must test these,
# not values that a relabel below has already changed
s0 = df["sanctioning_state_iso3"].copy()
t0 = df["sanctioned_state_iso3"].copy()

# =====================================================================
# STEP 1 — mark rows to DROP  (row goes if EITHER side hits a drop rule)
# =====================================================================
def _drop(code):   # small mask helper, not the recoding logic itself
    return (
        (code == "")                                    # terrorist orgs / non-state
        | (code == "BYS")                               # Byelorussian SSR (UN-seat artifact)
        | ((code == "UKR") & (yr <= 1990))              # Ukrainian SSR seat
        | ((code == "SVU") & (yr >= 1990))              # USSR 1990-91 tail (Russia takes over)
        | ((code == "RUS") & (yr <  1990))              # pre-1990 RUS duplicates
        | ((code == "KSV") & (yr <= 2007))              # premature/erroneous Kosovo (case 663)
        | ((code == "ARM") & (yr <  1991))              # pre-independence 'bleed' below
        | ((code == "AZE") & (yr <  1991))
        | ((code == "EST") & (yr <  1991))
        | ((code == "LTU") & (yr <  1991))
        | ((code == "LVA") & (yr <  1991))
        | ((code == "BIH") & (yr <  1992))
        | ((code == "HRV") & (yr <  1992))
        | ((code == "SVN") & (yr <  1992))
        | ((code == "SGP") & (yr <  1965))
        | ((code == "GNB") & (yr <  1974))
        | ((code == "MOZ") & (yr <  1975))
        | ((code == "ERI") & (yr <  1993))              # ADDED 2026-10-20: Eritrea before independence
    )
drop_mask = _drop(s0) | _drop(t0)

# =====================================================================
# STEP 2 — mark rows for a SEPARATE side table (kept, not merged)
# =====================================================================
separate = {"RHO", "PSE", "HKG", "ESH", "VAT", "MSR"}   # RHO kept aside (no Zimbabwe change)
# ADDED 2026-10-20: case 179 (Cyprus vs "Cyprus (Northern)") — GSDB gives Northern Cyprus the
# code CYP, so Cyprus would sanction itself; Northern Cyprus is not a GW state -> set aside.
north_cyprus = df["sanctioned_state"].eq("Cyprus (Northern)") | df["sanctioning_state"].eq("Cyprus (Northern)")
separate_mask = (s0.isin(separate) | t0.isin(separate) | north_cyprus) & ~drop_mask

# =====================================================================
# STEP 3 — relabel codes (and the two clean names), on both columns
# =====================================================================
# 3a. simple same-polity renames (all years)
df[iso_cols]  = df[iso_cols].replace({"DHY": "BEN", "HVO": "BFA"})
df[name_cols] = df[name_cols].replace({"Dahomey": "Benin", "Upper Volta": "Burkina Faso"})
# 3b. folds (all years)
df[iso_cols]  = df[iso_cols].replace({"GIB": "GBR", "COK": "NZL", "NIU": "NZL"})
# 3c. year-conditional relabels (test the original codes s0/t0, write to the live column)
for col, orig in [("sanctioning_state_iso3", s0), ("sanctioned_state_iso3", t0)]:
    df.loc[(orig == "SVU") & (yr <  1990), col] = "RUS"   # Soviet sanctions -> single RUS
    df.loc[(orig == "SRB") & (yr <= 2005), col] = "YUG"   # pre-2006 = Yugoslavia
    df.loc[(orig == "MNE") & (yr <= 2005), col] = "YUG"
    df.loc[(orig == "DDR") & (yr >= 1991), col] = "DEU"   # post-reunification residue
    df.loc[(orig == "CSK") & (yr >= 1993), col] = "CZE"   # post-dissolution residue
    df.loc[(orig == "CZE") & (yr <= 1992), col] = "CSK"   # successor code before the split
    df.loc[(orig == "SVK") & (yr <= 1992), col] = "CSK"
    df.loc[(orig == "VNM") & (yr >= 1976), col] = "VDR"   # unified Vietnam is VDR in base
    #df.loc[(orig == "ERI") & (yr <= 1992), col] = "ETH"   # Eritrea within Ethiopia pre-1993

# =====================================================================
# STEP 4 — split into buckets
# =====================================================================
panel = df[~drop_mask & ~separate_mask].copy()   # merge into the base (dedupe first!)
side  = df[separate_mask].copy()                  # RHO/PSE/HKG/ESH/VAT/MSR
# dropped = df[drop_mask]

print("merge:", len(panel), "| separate:", len(side), "| drop:", int(drop_mask.sum()))

# ADDED 2026-10-20: keep a record of the set-aside rows; drop self-sanctions
side.to_csv(OUT / "gsdb_set_aside.csv", index=False)
print("set aside by entity:", side["sanctioned_state"].where(side["sanctioned_state_iso3"].isin(separate)
      | side["sanctioned_state"].eq("Cyprus (Northern)"), side["sanctioning_state"]).value_counts().to_dict())
# Self-sanctions: after the recoding (e.g. GDR -> DEU from 1991, Serbia/Montenegro -> YUG
# to 2005, North/South Vietnam -> VDR from 1976) some rows have sender == target, i.e. a
# state "sanctioning itself". These are recoding residues -> dropped and listed.
self_mask = panel["sanctioning_state_iso3"] == panel["sanctioned_state_iso3"]
self_rows = panel[self_mask]
self_rows.to_csv(OUT / "gsdb_self_dyads_dropped.csv", index=False)
print("self-dyads dropped (sender == target after recoding):", len(self_rows))
if len(self_rows):
    print(self_rows[["case_id", "sanctioning_state", "sanctioned_state", "year"]].to_string())
panel = panel[~self_mask].copy()

# =====================================================================
# STEP 4a — ADDED 2026-10-20: attribution of the "Yugoslavia" cases
# =====================================================================
# GSDB's case file names "Yugoslavia" as the target of cases 419-422, 469, 470,
# 619-621, 636-638, 660, 676, 732, but the dyadic file copies them to every
# successor republic. gsdb_yugoslavia_attribution.csv says, per case x republic,
# whether the case is kept (arms embargo only, with republic-specific end year)
# or dropped. Rules and sources: data/README_yugoslavia.md.
TYPE_COLS = ["arms", "military", "trade", "financial", "travel", "other"]
rules = pd.read_csv(ROOT / "data" / "scripts" / "cleaning" / "gsdb_yugoslavia_attribution.csv")
rule_of = {(int(r.case_id), r.target_iso3): r for r in rules.itertuples()}
yugo_cases = set(rules["case_id"].astype(int))
case_flags = pd.read_csv(RAW / "GSDB_V4.csv").set_index("case_id")[TYPE_COLS]

panel_yr = pd.to_datetime(panel["year"]).dt.year
in_scope = panel["sanctioned_state_iso3"].isin(set(rules["target_iso3"]))
log_rows, drop_idx = [], []
for i in panel.index[in_scope]:
    cases = [int(c) for c in str(panel.at[i, "case_id"]).split(",") if c.strip()]
    if not yugo_cases.intersection(cases):
        continue
    target, y = panel.at[i, "sanctioned_state_iso3"], panel_yr.at[i]
    kept, flags = [], dict.fromkeys(TYPE_COLS, 0)
    for c in cases:
        if c in yugo_cases:
            r = rule_of.get((c, target))
            if r is None:
                raise ValueError(f"no attribution rule for case {c} and target {target}")
            if r.action == "keep_arms_only" and r.keep_from <= y <= r.keep_to:
                kept.append(c)
                flags["arms"] = 1
        else:                                   # a case that names the republic itself
            kept.append(c)
            for t in TYPE_COLS:
                flags[t] = max(flags[t], int(case_flags.at[c, t]))
    before = {t: int(panel.at[i, t]) for t in TYPE_COLS}
    log_rows.append(dict(target=target, year=y, sender=panel.at[i, "sanctioning_state_iso3"],
                         case_id_before=panel.at[i, "case_id"], case_id_after=",".join(map(str, kept)),
                         **{f"{t}_before": before[t] for t in TYPE_COLS},
                         **{f"{t}_after": (flags[t] if kept else 0) for t in TYPE_COLS}))
    if kept:
        panel.at[i, "case_id"] = ",".join(map(str, kept))
        for t in TYPE_COLS:
            panel.at[i, t] = flags[t]
    else:
        drop_idx.append(i)
panel = panel.drop(index=drop_idx)
attr_log = pd.DataFrame(log_rows)
attr_log.to_csv(OUT / "gsdb_yugoslavia_attribution_log.csv", index=False)
print("Yugoslavia attribution: rows touched", len(attr_log), "| dropped", len(drop_idx),
      "| kept (arms only)", len(attr_log) - len(drop_idx))
print(attr_log.assign(dropped=attr_log["case_id_after"].eq("")).groupby(["target", "dropped"]).size().to_string())

# =====================================================================
# STEP 4b — attach Gleditsch-Ward codes (for the *_gw counts)
# =====================================================================
gw_cw = pd.read_csv(ROOT / "data" / "clean" / "base" / "base.csv", usecols=["gwcode", "year", "iso3c"])
gw_cw = gw_cw.dropna(subset=["iso3c"])
assert not gw_cw.duplicated(["iso3c", "year"]).any(), "iso3c-year must identify one GW state"
gw_cw["year"] = pd.to_datetime(gw_cw["year"].astype(str), format="%Y")
panel = (
    panel
    .merge(gw_cw.rename(columns={"iso3c": "sanctioning_state_iso3", "gwcode": "sanctioning_gwcode"}),
           on=["sanctioning_state_iso3", "year"], how="left")
    .merge(gw_cw.rename(columns={"iso3c": "sanctioned_state_iso3", "gwcode": "sanctioned_gwcode"}),
           on=["sanctioned_state_iso3", "year"], how="left")
)
for side in ["sanctioning", "sanctioned"]:
    miss = panel[panel[f"{side}_gwcode"].isna()]
    print(f"{side} rows without a GW state (not counted in *_gw):", len(miss))
    if len(miss):
        print(miss.groupby(f"{side}_state_iso3")["year"].agg(["min", "max", "size"]).to_string())

# =====================================================================
# STEP 5 — aggregate to country-year
# =====================================================================
received_sanctions = (
    panel.groupby(['sanctioned_state_iso3', 'year'])
    .agg(
        num_sanctioners=('sanctioning_state', 'nunique'),
        num_sanctioners_gw=('sanctioning_gwcode', 'nunique'),
        n_arms_received=('arms', 'sum'),
        n_military_received=('military', 'sum'),
        n_trade_received=('trade', 'sum'),
        n_financial_received=('financial', 'sum'),
        n_travel_received=('travel', 'sum'),
        n_other_received=('other', 'sum'),
    )
    .reset_index()
    .rename(columns={'sanctioned_state_iso3': 'country_iso3'})
)

outgoing_sanctions = (
    panel.groupby(['sanctioning_state_iso3', 'year'])
    .agg(
        num_targets_sanctioned=('sanctioned_state', 'nunique'),
        num_targets_sanctioned_gw=('sanctioned_gwcode', 'nunique'),
        n_arms_sent=('arms', 'sum'),
        n_military_sent=('military', 'sum'),
        n_trade_sent=('trade', 'sum'),
        n_financial_sent=('financial', 'sum'),
        n_travel_sent=('travel', 'sum'),
        n_other_sent=('other', 'sum'),
    )
    .reset_index()
    .rename(columns={'sanctioning_state_iso3': 'country_iso3'})
)
# REMOVED 2026-10-20: the original notebook set all received counts of Slovenia
# 1991-1996 to 0. Removed after checking that the UN arms embargo (res. 713) covered
# the whole territory of former Yugoslavia, incl. Slovenia, until 1996 (see data/README.md, S3).

# =====================================================================
# STEP 5b — ADDED 2026-10-20: case-based alternative measures (received side)
# =====================================================================
# num_sanctioners counts senders, and GSDB codes a UN (or EU) case as one row per
# member state, so it jumps to ~190 under any UN regime. These measures count CASES
# (sanction episodes) and mark who imposed them (sender of the case in GSDB_V4.csv).
case_sender = pd.read_csv(RAW / "GSDB_V4.csv").set_index("case_id")["sanctioning_state"].astype(str)
sender_tokens = case_sender.str.split(r",\s*")
is_un = sender_tokens.apply(lambda t: "UN" in t)
is_eu = sender_tokens.apply(lambda t: bool({"EU", "EEC"} & set(t)))
is_us = sender_tokens.apply(lambda t: "United States" in t)
is_ru = sender_tokens.apply(lambda t: bool({"Russia", "Soviet Union"} & set(t)))   # ADDED 2026-10-20

rc = panel[["sanctioned_state_iso3", "year", "case_id"]].copy()
rc["case"] = rc["case_id"].astype(str).str.split(",")
rc = rc.explode("case")
rc["case"] = rc["case"].str.strip().astype(int)
assert rc["case"].isin(case_sender.index).all(), "case id missing in GSDB_V4.csv"
rc = rc.drop_duplicates(["sanctioned_state_iso3", "year", "case"])
rc["un"], rc["eu"], rc["us"] = rc["case"].map(is_un), rc["case"].map(is_eu), rc["case"].map(is_us)
rc["ru"] = rc["case"].map(is_ru)
cases_cy = (rc.groupby(["sanctioned_state_iso3", "year"])
              .agg(n_cases_received=("case", "nunique"),
                   un_sanction=("un", "max"), eu_sanction=("eu", "max"), us_sanction=("us", "max"),
                   ru_sanction=("ru", "max"))
              .reset_index().rename(columns={"sanctioned_state_iso3": "country_iso3"}))
cases_cy["any_sanction"] = (cases_cy["n_cases_received"] > 0).astype(int)
for c in ["un_sanction", "eu_sanction", "us_sanction", "ru_sanction"]:
    cases_cy[c] = cases_cy[c].astype(int)
received_sanctions = received_sanctions.merge(cases_cy, on=["country_iso3", "year"], how="left")
print("case-based measures: target-years", len(cases_cy), "| with UN case:", int(cases_cy["un_sanction"].sum()),
      "| EU:", int(cases_cy["eu_sanction"].sum()), "| US:", int(cases_cy["us_sanction"].sum()),
      "| Russia/SU:", int(cases_cy["ru_sanction"].sum()))

# duplicate check (printed to the log; should be empty)
dup_mask = received_sanctions.duplicated(subset=["year", "country_iso3"], keep=False)
print("duplicate country-years in received:", int(dup_mask.sum()))
print("target-years where name count != gwcode count:",
      int((received_sanctions["num_sanctioners"] != received_sanctions["num_sanctioners_gw"]).sum()), "of", len(received_sanctions))
print("sender-years where name count != gwcode count:",
      int((outgoing_sanctions["num_targets_sanctioned"] != outgoing_sanctions["num_targets_sanctioned_gw"]).sum()), "of", len(outgoing_sanctions))

received_sanctions.to_csv(OUT / "gsdb_received.csv", index=False)
outgoing_sanctions.to_csv(OUT / "gsdb_sent.csv", index=False)
print("Wrote", OUT / "gsdb_received.csv", received_sanctions.shape)
print("Wrote", OUT / "gsdb_sent.csv", outgoing_sanctions.shape)
