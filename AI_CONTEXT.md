# AI context: sanctions & violence project (handoff for the next Cowork session)

Written 20 Oct 2026 at the end of a 2-day Cowork session. Read this first, then `README.md`,
`data/README.md` (all data decisions + change log) and `data/README_yugoslavia.md`.

## 1. Project in one paragraph

RA project (LMU, Sunde). Country-year panel of Gleditsch–Ward (GW) states, **1950–2023**, combining
sanctions (GSDB v4), organized violence (UCDP OV-CY v26.1), GDELT 1.0 conflict events, democracy and
GDP/population (peacesciencer, extended with UN WPP / World Bank via OWID). Research question: dynamic
interplay of sanctions and violence; current estimator is a panel VAR in R (`panelvar`).
Final dataset: `data/processed/sanctions_violence/sanctions_violence_panel.csv` (11,989 rows × 131 cols).

## 2. Folders — important

| Path | Status |
|---|---|
| `~/Documents/LMU_Life/RA_Work_Sunde/sanctions and violence` | **ORIGINAL — never modify.** User's old messy project (notebooks). |
| `~/Documents/LMU_Life/RA_Work_Sunde/sanctions and violence - working copy` | **All work happens here.** Reorganized project. |

The user explicitly wants every change made only in the working copy.

## 3. Layout of the working copy (G1 structure requested by the user)

```
data/raw/{dataset}/          raw, never modified (gsdb, ucdp_ov, ucdp_prio, gdelt, states, owid, population, gdp-per-capita-worldbank)
data/clean/{dataset}/        cleaning outputs (base, gsdb, ucdp_ov, gdelt, population, gdp)
data/processed/sanctions_violence/   final panel + intermediate/ + checks/
data/scripts/cleaning/       clean_base.R, clean_gsdb.py, clean_ucdp_ov.py, clean_gdelt.py, clean_population.py, clean_gdp.py
                             + hand-made tables: gsdb_yugoslavia_attribution.csv, gdelt_country_crosswalk.csv, gdelt_gw_assignments.csv
data/scripts/processing/     process_sanctions_violence.py
data/scripts/checks/         check_replication.py
data/logs/                   one log per script run
empirics/scripts/            00_setup.R (shared R setup), 02_descriptives.R (5 figures), 01_unit_root_tests.Rmd, 02_panel_var.Rmd (old, not in master)
empirics/results/            figures/descriptives/, logs/, legacy_renders/
archive/                     old notebooks, legacy outputs, baseline/ (frozen outputs for the check), misc/
master.py                    runs everything (Python + R via Rscript), logs, --check / --set-baseline
setup_renv.R                 R environment (renv) — created, NOT yet run by the user
```

## 4. How to run

```bash
uv sync                                   # Python env (.venv in project; Python 3.13; pandas 3.0.3)
Rscript setup_renv.R                      # R env (renv) — first run still pending on the Mac
uv run python master.py                   # data pipeline (cleaning + processing)
uv run python master.py --stage empirics  # only the R descriptive figures
uv run python master.py --check           # compare outputs with archive/baseline (any change reported)
uv run python master.py --set-baseline    # freeze current outputs as the new baseline after a logged change
```

## 5. Working environment notes for the AI (learned the hard way)

- The user's files are reached through the device bridge (`device_bash` = Linux ARM VM with the folders mounted).
  **No R in the VM, no sudo.** The cloud container has R but **CRAN is blocked** (and github.com archives) → R code
  cannot be run by the AI; the user runs it on the Mac (`Rscript`, master.py) and the AI reads the logs in `data/logs/`.
- Python testing in the VM: use a venv **outside** the project, e.g. `UV_PROJECT_ENVIRONMENT=$HOME/venv-sv uv sync --frozen`,
  then `$HOME/venv-sv/bin/python master.py --skip-r`. Never create a Linux `.venv` inside the project (the Mac uses it).
  (The VM home may be reset between sessions — recreate if needed.)
- Outputs produced in the VM differ from Mac outputs in the last float digit (~1e-15, pandas CSV parser is platform-dependent).
  The check reports this as "floating-point noise only". Exact comparisons must use Mac-produced files.
- Network from the VM/container: World Bank, UN, OWID, CRAN are blocked; raw.githubusercontent.com works from the container.
  New raw data must be downloaded by the user into `data/raw/...`.
- Deleting files in the user's folders is not allowed without permission → move to `archive/` instead.

## 6. Conventions the user agreed to

1. **Every data change is logged** in `data/README.md` (decision entry with ID, e.g. S9/P5/G9, + change-log row).
   Yugoslavia-specific rules live in `data/README_yugoslavia.md`.
2. After an intentional change: verify against the previous output (only the expected cells change), then the user runs
   `master.py --set-baseline` on the Mac.
3. Hand-made decisions go into small, visible CSV tables (not hidden code): GSDB Yugoslavia attribution, GDELT crosswalk,
   GDELT year-specific assignments.
4. Refactors must reproduce the data exactly (the first reorganization was a verified pure refactor).
5. Analysis discipline (discussed): fix the main specification in a dated analysis plan before estimating; robustness as a
   spec list; avoid graphs that relate sanctions to violence before the plan is fixed.
6. User preferences: works with **uv** (not bash scripts), wants R for empirics, Python for cleaning; concise answers;
   asks "why" — explain decisions; does not want changes to things that are correctly coded (e.g. GSDB group cases).

## 7. What was done (summary — details in `data/README.md`)

- Reorganized the project (raw/clean/processed, scripts per dataset), converted notebooks to scripts, `master.py` with logs,
  replication check (first vs old notebooks, now vs frozen baseline). Old notebooks/outputs in `archive/`.
- **Base (clean_base.R):** conflict-type counts fixed (peacesciencer stores type as text; were all 0). Yugoslavia-2006 row dropped (only Serbia in 2006).
- **GSDB:** Slovenia zero rule removed; Yugoslavia cases attributed per republic (arms embargoes only for SVN/HRV/BIH/MKD, rule table);
  Eritrea < 1993 dropped; Northern Cyprus (case 179) set aside; 9 self-sanction rows from recoding dropped; target scan of all cases
  (group cases 599 ECOWAS, 12/13 CoCom, 685 ICC, 199 Arab League, 995 Russia vs EU **kept as coded** — documented, not errors).
- **New sanction variables:** `num_sanctioners_gw`, `num_targets_sanctioned_gw`, `n_cases_received`, `any_sanction`,
  `un_sanction`, `eu_sanction`, `us_sanction`, `ru_sanction`. Note: `num_sanctioners` jumps to ~190 under any UN case (GSDB codes UN cases per member state).
- **UCDP:** Serbia recode from 2006; per-capita deaths missing (not 0) before 1989; per capita = per 100,000.
- **GDELT:** fixed crosswalk (all 258 names audited; country_converter no longer used at run time), year-specific assignment to historical
  states, weighted combination of units, missing (not 0) after 2021 and for non-separable states.
- **Population/GDP:** `pop_ext` and `gdp_ext` = original peacesciencer series to 2019, extended 2020–23 with WPP (OWID) / World Bank (OWID) growth rates.
- Panel starts 1950; ex-Yugoslavia dummies `ex_yugo`, `ex_yugo_1991_2016`; merge leftovers dropped (`iso3c` single column).
- 5 descriptive figures (R script `02_descriptives.R`; earlier Python version in `archive/misc/`).
- renv setup script + `00_setup.R`; master runs only the figures in the empirics stage.

## 8. Status at the end of this session

| Item | Status |
|---|---|
| Data pipeline | complete; last Mac run + baseline at 20 Oct 17:27 |
| `ru_sanction` (added after that baseline) | **user must run** `uv run python master.py --set-baseline` on the Mac |
| `setup_renv.R` | written, **not yet run** (may fail for `panelvar` if archived on CRAN) |
| `02_descriptives.R` | written, **never run** (AI could not test R) — check the figures after the first run |
| `01_unit_root_tests.Rmd`, `02_panel_var.Rmd` | not reproducible yet (use `na_check` from an old R session; missing library calls); data path updated; `iso3c_x` → `iso3c` if used |
| Git | repo exists but **no commit yet**; `.gitignore` should exclude `.venv/`, `data/raw/`, `data/logs/`, `.RData`, `renv/library` |

## 9. Known gaps (accepted) and open points

- GDP 2020–23 missing for 12 states (incl. Syria, Yemen, Venezuela); GDELT ends 2021; UCDP starts 1989.
- Population levels pwtpop vs WPP differ for Syria/Lebanon/Yemen (−15/+20/−18%) → possible robustness version.
- Yugoslavia remaining verification points: "relatively resolved", controlled by dummies.
- Main sanctions measure not chosen yet (names vs GW vs case-based) — research-design decision for the analysis plan.

## 10. Suggested next steps

1. Run on the Mac: `Rscript setup_renv.R`, `uv run python master.py --set-baseline`, `uv run python master.py --stage empirics`; fix errors from the logs.
2. First git commit (after `.gitignore`).
3. Write `empirics/ANALYSIS_PLAN.md` (question, mechanism, main spec, robustness list) and commit it before estimating.
4. Restructure the R analysis: `01_prepare_sample.R` (replaces `na_check`, logs exclusions), `functions.R`, `specs.R`,
   `03_unit_roots.R`, `04_pvar.R`, `05_report.Rmd`; migrate the two old notebooks with unchanged logic; add to `master.py`.
5. Optional: codebook (`codebook.csv`, one row per variable with role main/alternative/control/ignore).
