"""
check_replication.py

DEFAULT (since 2026-10-20): compares the pipeline outputs with the frozen baseline in
archive/baseline/ -> any change is reported.
    python data/scripts/checks/check_replication.py              # check
    python data/scripts/checks/check_replication.py --set-baseline  # freeze current outputs
    python data/scripts/checks/check_replication.py --legacy     # old comparison with the notebooks

--- original description (legacy mode) ---
Compare the outputs of the reorganised pipeline with the outputs of the old
notebooks (kept in archive/legacy_outputs/). Exact, cell-by-cell comparison of
the CSV text; for differing numeric cells the max absolute difference is shown.

Run after the pipeline:  python data/scripts/checks/check_replication.py
Exit code 0 = everything identical.

Note: the legacy files were produced on your Mac. Run on another machine
(e.g. Linux), even the OLD notebooks give last-digit differences
(~1e-14) in some float columns, because pandas' default CSV float parser is
platform dependent. The summary therefore also says whether all differences
are below a relative tolerance of 1e-12 ("floating-point noise only").
"""
import sys
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[3]
LEG = ROOT / "archive" / "legacy_outputs"
NEW_PANEL = ROOT / "data" / "processed" / "sanctions_violence" / "sanctions_violence_panel.csv"
CHECKS = ROOT / "data" / "processed" / "sanctions_violence" / "checks"
INTER = ROOT / "data" / "processed" / "sanctions_violence" / "intermediate"

# (label, legacy file, new file, compare only the legacy file's columns?)
PAIRS = [
    ("base (R)",            LEG / "data_clean" / "final.csv",                               ROOT / "data" / "clean" / "base" / "base.csv", False),
    ("panel (final)",       LEG / "data_clean" / "country_year_sanctions_coflict_gdelt.csv", NEW_PANEL, False),
    ("sanctions stage",     LEG / "data_clean" / "country_year_sanctions.csv",               INTER / "country_year_sanctions.csv", False),
    ("conflict stage",      LEG / "data_clean" / "country_year_sanctions_coflict.csv",       INTER / "country_year_sanctions_conflict.csv", False),
    ("orphans received",    LEG / "orphans" / "orphans_recieved.csv",                        CHECKS / "orphans_recieved.csv", False),
    ("orphans outgoing",    LEG / "orphans" / "orphans_outgoing.csv",                        CHECKS / "orphans_outgoing.csv", False),
    ("base crosswalk",      LEG / "root" / "base_cross.csv",                                 CHECKS / "base_cross.csv", False),
]


def read(p):
    return pd.read_csv(p, dtype=str, keep_default_na=False, encoding_errors="replace")


# Intentional, documented changes (see data/README.md change log). Cells matching these
# rules are not compared; each rule is reported with the number of cells it covers.
RECEIVED_COLS = ["num_sanctioners", "n_arms_received", "n_military_received", "n_trade_received",
                 "n_financial_received", "n_travel_received", "n_other_received"]
SENT_COLS = ["num_targets_sanctioned", "n_arms_sent", "n_military_sent", "n_trade_sent",
             "n_financial_sent", "n_travel_sent", "n_other_sent"]
KNOWN_CHANGES = [
    dict(desc="2026-10-20 Slovenia 1992-96 zero rule removed",
         iso_col="iso3c", iso="SVN", years=(1991, 1996), cols=RECEIVED_COLS),
    dict(desc="2026-10-20 conflict-type filter fixed in clean_base.R (text labels)",
         iso_col=None, iso=None, years=(1946, 2023),
         cols=["n_conflicts_intra", "n_conflicts_inter", "n_conflicts_extra"]),
    dict(desc="2026-10-20 Yugoslavia 2006 row dropped (only Serbia in 2006)",
         drop=dict(col="gwcode", value="345", years=(2006, 2006))),
    dict(desc="2026-10-20 Eritrea before 1993 dropped from GSDB (no longer an orphan)",
         drop=dict(col="country_iso3", value="ERI", years=(1977, 1992))),
    dict(desc="2026-10-20 Eritrea before 1993 dropped from GSDB: US targets count (case 208)",
         iso_col="iso3c", iso="USA", years=(1977, 1992),
         cols=["num_targets_sanctioned", "n_other_sent"]),
    dict(desc="2026-10-20 Yugoslavia cases attributed per republic (received side)",
         iso_col="iso3c", iso=["SVN", "HRV", "BIH", "MKD", "MNE"], years=(1991, 2016), cols=RECEIVED_COLS),
    dict(desc="2026-10-20 Yugoslavia cases attributed per republic (senders lose republic targets)",
         iso_col=None, iso=None, years=(1991, 2016), cols=SENT_COLS),
    dict(desc="2026-10-20 per-capita UCDP variables missing (not 0) before 1989",
         iso_col=None, iso=None, years=(1946, 1988), cols="UCDP_PC"),
    dict(desc="2026-10-20 per-capita UCDP variables 2020-2023 now filled (population extended with WPP)",
         iso_col=None, iso=None, years=(2020, 2023), cols="UCDP_PC"),
    dict(desc="2026-10-20 GDELT: no zero-fill after 2021 (end of GDELT)",
         iso_col=None, iso=None, years=(2022, 2023), cols="GDELT"),
    dict(desc="2026-10-20 GDELT: states of the time get their GDELT data / non-separable states missing",
         iso_col="gwcode", iso=["816", "345", "340", "315", "365", "530", "625", "850",
                                "265", "680", "396", "397"], years=(1979, 2021), cols="GDELT"),
    dict(desc="2026-10-20 Serbia 2006 now matched to UCDP (345->340 from 2006)",
         iso_col="gwcode", iso="340", years=(2006, 2006), cols="UCDP"),
]


GDELT_COLS = [f"{r}_{m}" for m in ("norm1000", "goldstein")
              for r in ("assault", "coerce", "fight", "mass_violence", "total_violence")] + \
             ["Year", "CountryCode", "CountryName", "iso3c_y"]


def _ucdp_cols():
    p = ROOT / "data" / "clean" / "ucdp_ov" / "ucdp_ov_cy.csv"
    if not p.exists():
        return []
    base_cols = [c for c in pd.read_csv(p, nrows=0).columns if c != "year"]
    return base_cols + [c + "_pc" for c in base_cols]

TOL = 1e-12
noise_only = True


def compare(label, old_p, new_p, subset):
    global noise_only
    if not new_p.exists():
        noise_only = False
        print(f"[MISSING] {label}: {new_p.relative_to(ROOT)} not found (run the pipeline first)")
        return False
    old, new = read(old_p), read(new_p)
    if subset:
        missing = [c for c in old.columns if c not in new.columns]
        if missing:
            noise_only = False
            print(f"[DIFF] {label}: columns missing in new file: {missing}")
            return False
        new = new[list(old.columns)]
    problems = []
    added = [c for c in new.columns if c not in old.columns]
    if added and all(c in new.columns for c in old.columns):
        print(f"[NOTE] {label}: new columns not in the legacy file (not compared): {added}")
        new = new[list(old.columns)]
    for kc in KNOWN_CHANGES:
        if "drop" in kc:
            d = kc["drop"]
            if d["col"] in old.columns and "year" in old.columns:
                hit = (old[d["col"]] == d["value"]) & old["year"].str[:4].astype(int).between(*d["years"])
                if hit.any() and len(old) == len(new) + int(hit.sum()):
                    print(f"[KNOWN CHANGE] {label}: {kc['desc']} -> {int(hit.sum())} row(s) removed, not compared")
                    old = old[~hit].reset_index(drop=True)
            continue
    for kc in KNOWN_CHANGES:
        if "drop" in kc:
            continue
        kcols = {"UCDP": _ucdp_cols(), "UCDP_PC": [c for c in _ucdp_cols() if c.endswith("_pc")], "GDELT": GDELT_COLS}.get(kc["cols"], kc["cols"]) if isinstance(kc["cols"], str) else kc["cols"]
        cols = [c for c in kcols if c in old.columns and c in new.columns]
        if "year" not in old.columns or not cols or len(old) != len(new):
            continue
        yrs = old["year"].str[:4].astype(int)
        rows = yrs.between(*kc["years"])
        if kc["iso_col"] is not None:
            iso_col = next((c for c in (kc["iso_col"], kc["iso_col"] + "_x") if c in old.columns), None)
            if iso_col is None:
                continue
            isos = kc["iso"] if isinstance(kc["iso"], list) else [kc["iso"]]
            rows &= old[iso_col].isin(isos)
        n = int(old.loc[rows, cols].ne(new.loc[rows, cols]).sum().sum())
        if rows.any():
            print(f"[KNOWN CHANGE] {label}: {kc['desc']} -> {n} cells differ, not compared")
            new = new.copy()
            new.loc[rows, cols] = old.loc[rows, cols]
    if list(old.columns) != list(new.columns):
        problems.append(f"column names/order differ:\n   old-only {sorted(set(old.columns)-set(new.columns))}\n   new-only {sorted(set(new.columns)-set(old.columns))}")
    if old.shape[0] != new.shape[0]:
        problems.append(f"row count differs: old {old.shape[0]} vs new {new.shape[0]}")
    if problems:
        noise_only = False
    if not problems:
        neq = old.ne(new)
        bad = neq.sum()
        bad = bad[bad > 0]
        for col, n in bad.items():
            o = pd.to_numeric(old[col], errors="coerce")
            w = pd.to_numeric(new[col], errors="coerce")
            both = neq[col] & o.notna() & w.notna()
            extra = ""
            if both.any():
                rel = ((o[both] - w[both]).abs() / pd.concat([o[both].abs(), w[both].abs()], axis=1).max(axis=1).clip(lower=1e-300)).max()
                extra = f", max |diff| = {(o[both] - w[both]).abs().max():.3g}, max rel diff = {rel:.3g}"
            if not (both.sum() == n and rel <= TOL):
                noise_only = False
            i = neq[col].idxmax()
            problems.append(f"{col}: {n} cells differ{extra} (e.g. row {i}: old={old.at[i, col]!r} new={new.at[i, col]!r})")
    if problems:
        print(f"[DIFF] {label}  ({old_p.relative_to(ROOT)} vs {new_p.relative_to(ROOT)})")
        for p in problems:
            print("   -", p)
        return False
    print(f"[IDENTICAL] {label}: {old.shape[0]} rows x {old.shape[1]} cols")
    return True


# ---------------------------------------------------------------------------
# BASELINE MODE (default since 2026-10-20): compare with a frozen copy of the
# current outputs in archive/baseline/. Any difference is reported; nothing is
# treated as a known change. Freeze a new baseline after an intentional change
# with --set-baseline (and log the change in data/README.md).
# ---------------------------------------------------------------------------
import shutil
from datetime import datetime

BASELINE = ROOT / "archive" / "baseline"
BASELINE_FILES = {
    "base.csv": ROOT / "data" / "clean" / "base" / "base.csv",
    "gsdb_received.csv": ROOT / "data" / "clean" / "gsdb" / "gsdb_received.csv",
    "gsdb_sent.csv": ROOT / "data" / "clean" / "gsdb" / "gsdb_sent.csv",
    "ucdp_ov_cy.csv": ROOT / "data" / "clean" / "ucdp_ov" / "ucdp_ov_cy.csv",
    "gdelt_cy.csv": ROOT / "data" / "clean" / "gdelt" / "gdelt_cy.csv",
    "wpp_population.csv": ROOT / "data" / "clean" / "population" / "wpp_population.csv",
    "wb_gdppc.csv": ROOT / "data" / "clean" / "gdp" / "wb_gdppc.csv",
    "sanctions_violence_panel.csv": NEW_PANEL,
}


def set_baseline():
    BASELINE.mkdir(parents=True, exist_ok=True)
    for name, src in BASELINE_FILES.items():
        shutil.copy2(src, BASELINE / name)
    (BASELINE / "BASELINE_INFO.txt").write_text(
        f"Baseline frozen {datetime.now():%Y-%m-%d %H:%M:%S} from the current pipeline outputs.\n")
    print("Baseline written to", BASELINE.relative_to(ROOT), "with", len(BASELINE_FILES), "files")


def check_baseline():
    global noise_only
    if not (BASELINE / "BASELINE_INFO.txt").exists():
        print("No baseline yet: run  python master.py --set-baseline  once (on the Mac).")
        noise_only = False
        return False
    print((BASELINE / "BASELINE_INFO.txt").read_text().strip())
    global KNOWN_CHANGES
    KNOWN_CHANGES = []                                    # baseline mode: everything counts
    return all([compare(name, BASELINE / name, src, False) for name, src in BASELINE_FILES.items()])


if __name__ == "__main__":
    if "--set-baseline" in sys.argv:
        set_baseline()
        sys.exit(0)
    if "--legacy" in sys.argv:
        # historical: comparison with the old notebooks (valid up to the 2026-10-20 15:00 version;
        # later changes - 1950 start, dropped columns - are not listed as known changes)
        ok = all([compare(*p) for p in PAIRS])
    else:
        ok = check_baseline()
    if ok:
        verdict = "all outputs replicate EXACTLY"
    elif noise_only:
        verdict = f"differences are floating-point noise only (all < {TOL:g} relative)"
    else:
        verdict = "SUBSTANTIVE differences found (see above)"
    print("\nRESULT:", verdict)
    sys.exit(0 if ok else 1)
