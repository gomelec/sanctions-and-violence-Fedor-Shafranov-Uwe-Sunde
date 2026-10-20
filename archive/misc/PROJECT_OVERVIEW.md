# Sanctions & Violence – project overview
*Reconstructed 19 Oct 2026 from the code and saved notebook outputs. The git repo has no commits yet, so this file is the only record of the order things run in.*

## 1. Research question (as implemented)
A country-year panel (Gleditsch–Ward state system, 1946–2023) to study the dynamic interplay between **sanctions received** (GSDB v4),
**organized-violence deaths** (UCDP OV-CY v26.1), **democracy** (V-Dem polyarchy) and **GDP per capita**, estimated as a **panel VAR**.
Reference papers: Stork (2020, Uppsala thesis), Urtuzuastigui & Koren (2024, *World Development*), Jaeger & Paserman (2008, cycle of violence).

## 2. Pipeline – run in this order
| # | File | Lang | Reads | Writes | What it does |
|---|------|------|-------|--------|--------------|
| 1 | `data_gather_R.ipynb` | R (Jupyter, IR kernel) | peacesciencer, states, countrycode | `base.csv`, `final.csv`*, `codelist_panel.csv`, `gwstates.csv`, `cowstates.csv` | GW state-year skeleton 1946–2023; ISO3 fixes for microstates/historic states + `successor_iso3c`; UCDP ACD conflict counts; adds polity2, V-Dem, simulated GDP/pop (`add_sim_gdp_pop`, **ends 2019**). |
| 2 | `create_sanction_data.ipynb` | Python | `data_clean/final.csv`, `GSDB_V4_dyadic.dta` | `data_clean/country_year_sanctions.csv`, `data/orphans/*.csv`, `base_cross.csv` | Recodes ISO3 (USSR/RUS, YUG, CSK, DDR, Vietnam …), drops non-state/artifact rows, aggregates received (`num_sanctioners`, `n_*_received`) and sent sanctions, merges on iso3c+year, zero-fills. |
| 3 | `Create_violence_data.ipynb` | Python | step 2 output, `OrganizedViolenceCYDataSet26_1.csv` | `data_clean/country_year_sanctions_coflict.csv` | Merges UCDP OV-CY on gwcode (Serbia 345→340 after 2006), zero-fills from 1989, builds `*_pc` = per 100,000 pop. |
| 4 | `create_gdelt_data.ipynb` | Python | step 3 output, `gdelt_conflict_1_0.csv` | `data_clean/country_year_sanctions_coflict_gdelt.csv`, `gdelt_cross.csv` | GDELT 1.0 CAMEO roots (coerce/assault/fight/mass violence): normalized events and Goldstein-weighted totals; zero-fills from 1979. **This is the analysis file** (12,310 rows × 123 cols, no duplicate country-years). |
| 5 | `R files/unit_root_testing.Rmd` | R | analysis file | – | IPS / Maddala-Wu / Choi tests on sanctions, GDP pc (level, trend, detrended), deaths pc, polyarchy. |
| 6 | `R files/1st_var.Rmd` | R | analysis file | – | 1989+ sample, detrended GDP; PVAR via GMM (FOD), Hahn–Kuersteiner, FE-OLS; stability; GIRFs with bootstrap bands. **Most recent work (16 Aug).** |

\* `final.csv` is written to the working directory and then sits in `data/data_clean/`.

## 3. Data
- `data/data_raw/` – originals: GSDB v4 (dyadic .dta, case csv, zip, `Var_Description.xlsx`), UCDP OV-CY 26.1, UCDP/PRIO ACD 26.1 (not used by code), GDELT conflict 1.0, codelist/gw/cow state lists.
- `data/data_clean/` – step outputs (above).
- `data/orphans/` – sanctions rows that found no state-year (only Eritrea 1977–92 as a target).
- `data/clean/merged_data/`, `data/logs/` – empty.
- Root OWID folders (`deaths-in-…`, `death-rate-in-…`) – downloaded 24 Jun, not used by any code.

## 4. Scratch / dead files (safe to archive)
`01_data_prep.ipynb` (abandoned pycountry approach), `Data_merge.ipynb` (empty), `pandas_check.ipynb` (scratch),
`Regressions_Conflict.Rmd/.nb.html` and `R files/Untitled.Rmd/.nb.html` (only library calls),
`R files/regressions_R.nb.html` (older render of unit_root_testing, no own .Rmd), `main.py` (uv stub),
root-level `base.csv`, `base_cross.csv`, `gdelt_cross.csv`, `codelist_panel.csv` (intermediate/crosswalk copies; root `codelist_panel.csv` differs from the one in `data_raw`),
`UCDP_OrganizedViolenceCY_Codebook_261 (1).pdf` (byte-identical duplicate).

## 5. Variable notes
- `cumulative_total_deaths_*_in_orgvio` is **not cumulative over time**: per the UCDP codebook it is the yearly sum over state-based, non-state and one-sided violence (a flow; confirmed – it falls in 106 of 201 countries).
- `*_pc` = deaths / `pwtpop` / 10 → per 100,000 (pwtpop is in millions). Missing from 2020 on because pwtpop ends 2019.
- `iso3c_x`/`iso3c_y`, `Year`/`year` are merge leftovers.

## 6. Issues to fix (priority order)
1. **Pre-1989 per-capita deaths are 0, not NA** (`Create_violence_data.ipynb`, the `_pc` loop uses `fillna(0)` on all years). All 5,572 rows from 1946–88 are 0. The unit-root test on deaths pc in `unit_root_testing.Rmd` uses the full sample and is contaminated; `1st_var.Rmd` is fine only because it filters to 1989+ (effective sample 1989–2019, since GDP/pop end in 2019). Open question: the FE-OLS/HK output reports up to 35 obs per country, more than 1989–2019 allows – check how `panelvar` treats the post-2019 NA rows.
2. **Stale GMM output in `1st_var.nb.html`**: the GMM tables show up to 72 obs per group (i.e. run before the 1989 filter, so with the artificial zeros), while the HK/FE-OLS tables show ≤35. Re-run the notebook top to bottom before citing any of it.
3. **Hidden state**: `unit_root_testing.Rmd` uses `na_check`, which is defined nowhere in the file (it lived in `.RData`). `1st_var.Rmd` calls `fread`, `here`, `pvargmm` without loading data.table/here/panelvar. Neither runs from a clean session.
4. **Hard-coded absolute paths** in every Python notebook – use relative paths (as `01_data_prep.ipynb` already does) or a `ROOT` variable.
5. The 4-variable GMM lag-selection loop fails (singular matrix); the reported GMM models are 2–3 variable versions.
6. Git: repo initialised, zero commits. Commit code; add `data/`, `.RData`, `*.nb.html` to `.gitignore`; turn off "save workspace" in RStudio.

## 7. Econometric notes for the next step
- Unit roots: first-generation tests (IPS, MW, Choi) assume cross-sectional independence, which sanctions (multilateral/EU episodes) and GDP clearly violate. Add Pesaran CIPS (`plm::cipstest`) and a CD test.
- GDP: MW does not reject in levels, rejects with trend. Country-specific linear detrending is defensible but Δlog GDP pc is the more standard and less arbitrary choice; check robustness.
- `num_sanctioners` is very persistent (AR ≈ 0.8–0.9) and a count of sanctioning *states*, so if GSDB lists a multilateral regime (e.g. EU) member by member, one decision moves it by many units (not yet checked in the data); consider log(1+x), an indicator, or the type-specific counts as robustness.
- Deaths pc are heavily zero-inflated and skewed; consider log(1+deaths pc) or the binary `sb_exist`/`os_exist`.
- With T ≈ 30, FE-OLS PVAR has Nickell bias ~1/T; GMM-FOD is the appropriate primary estimator, FE-OLS/HK as robustness. Report Hansen J and the instrument count.
- GIRFs avoid ordering assumptions but are not structural; if you want a causal reading, an ordering argument (e.g. sanctions respond to violence within the year, not vice versa) is needed for OIRFs.
- The current result to verify after fixes: lagged deaths → sanctions positive and significant (≈0.16–0.19 across estimators); sanctions → deaths ≈ 0 and insignificant.
