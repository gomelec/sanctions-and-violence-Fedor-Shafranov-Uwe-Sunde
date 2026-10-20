# Sanctions and violence

Country-year panel (Gleditsch–Ward states, 1946–2023) on sanctions (GSDB v4), organized violence (UCDP OV-CY v26.1),
GDELT conflict events, democracy and GDP; panel-VAR estimation in R.

## Run everything

```bash
uv sync                                   # once: Python environment (.venv) from pyproject.toml + uv.lock
Rscript setup_renv.R                      # once: R environment (renv/ + renv.lock), see below
uv run python master.py                   # data pipeline: cleaning + processing (Python and R steps)
uv run python master.py --stage empirics  # empirics: descriptive figures (R)
uv run python master.py --stage all       # data + empirics
uv run python master.py --check           # ... and compare with the frozen baseline (archive/baseline)
uv run python master.py --set-baseline    # ... and freeze the current outputs as the new baseline (after a logged change)
uv run python master.py --list            # see all steps
```

Other options: `--stage cleaning|processing|empirics|all`, `--only <step>`, `--skip-r`.
Each step writes one log per run to `data/logs/` (empirics: `empirics/results/logs/`).

**Python environment:** `pyproject.toml` + `uv.lock` (Python 3.13, see `.python-version`).
Without uv: `python3 -m venv .venv`, `.venv/bin/pip install -r requirements.txt`, `.venv/bin/python master.py`.

**R environment (renv):** `setup_renv.R` creates a project library and `renv.lock` with exact package versions
(first run) or restores them (later runs / other computers). The `.Rprofile` it creates activates the project
library automatically in RStudio and in `Rscript` calls from `master.py`. Packages: tidyverse, here, peacesciencer,
countrycode, states (data); data.table, plm, panelvar, fixest, modelsummary (analysis); rmarkdown, knitr (reports).
Add a package: `renv::install("pkg")` then `renv::snapshot(type = "all")`.

**Empirics scripts** (`empirics/scripts/`): every script starts with `source(here::here("empirics", "scripts", "00_setup.R"))`,
which loads the packages, defines all paths and the global analysis choices (sample years, exclusions, seed).
Scripts exchange results only through files in `empirics/results/` (no `.RData`). Currently in `master.py`:
`02_descriptives.R` (5 descriptive figures). `01_unit_root_tests.Rmd` and `02_panel_var.Rmd` are not in the
master yet (they still depend on objects from an old R session).

## Documentation

All cleaning and variable-construction decisions, with a change log: **`data/README.md`**.
Attribution of GSDB's "Yugoslavia" sanctions to the successor republics: **`data/README_yugoslavia.md`**.

## Layout

```
data/raw/{dataset}/          as downloaded; never modified          (see data/raw/README.md)
data/clean/{dataset}/        output of cleaning
data/processed/sanctions_violence/   analysis-ready panel (+ intermediate/ and checks/)
data/scripts/collection/     acquire_{dataset}.*   (none yet – raw files were downloaded by hand)
data/scripts/cleaning/       clean_{dataset}.*
data/scripts/processing/     process_sanctions_violence.py
data/scripts/checks/         check_replication.py
data/logs/                   one log per script run
empirics/scripts/            00_setup.R (shared setup), 02_descriptives.R (figures), estimation notebooks (R Markdown, not yet in master)
empirics/results/            rendered output, logs, legacy_renders/ (old notebook renders)
docs/papers/                 reference papers
archive/                     old notebooks, old Rmds and old outputs (untouched); baseline/ = frozen outputs for the check
master.py                    runs the pipeline
```

Datasets (`{dataset}` slugs): `base` (GW state-years from peacesciencer), `gsdb`, `ucdp_ov`, `gdelt`, `population` (UN WPP via OWID), `gdp` (World Bank via OWID);
raw only, not used by any script: `ucdp_prio`, `states`, `owid`.

## Pipeline

| Step | Script | Reads | Writes |
|---|---|---|---|
| clean_base | `data/scripts/cleaning/clean_base.R` | peacesciencer / states / countrycode packages | `data/clean/base/base.csv` |
| clean_gsdb | `data/scripts/cleaning/clean_gsdb.py` | `data/raw/gsdb/GSDB_V4_dyadic.dta` | `data/clean/gsdb/gsdb_received.csv`, `gsdb_sent.csv` |
| clean_ucdp_ov | `data/scripts/cleaning/clean_ucdp_ov.py` | `data/raw/ucdp_ov/OrganizedViolenceCYDataSet26_1.csv` | `data/clean/ucdp_ov/ucdp_ov_cy.csv` |
| clean_gdelt | `data/scripts/cleaning/clean_gdelt.py` | `data/raw/gdelt/gdelt_conflict_1_0.csv`, `gdelt_gw_assignments.csv` | `data/clean/gdelt/gdelt_cy.csv`, `gdelt_crosswalk.csv` |
| clean_population | `data/scripts/cleaning/clean_population.py` | `data/raw/population/population_owid_WPP2024_processed.csv` | `data/clean/population/wpp_population.csv` |
| clean_gdp | `data/scripts/cleaning/clean_gdp.py` | `data/raw/gdp-per-capita-worldbank/gdp-per-capita-worldbank.csv` | `data/clean/gdp/wb_gdppc.csv` |
| process_sanctions_violence | `data/scripts/processing/process_sanctions_violence.py` | all clean files | `data/processed/sanctions_violence/sanctions_violence_panel.csv` (+ `intermediate/`, `checks/`) |
| 01_unit_root_tests | `empirics/scripts/01_unit_root_tests.Rmd` | panel | `empirics/results/` |
| 02_panel_var | `empirics/scripts/02_panel_var.Rmd` | panel | `empirics/results/` |

## Where the old files went

| Old | New |
|---|---|
| `data_gather_R.ipynb` | `data/scripts/cleaning/clean_base.R` |
| `create_sanction_data.ipynb` | `clean_gsdb.py` + sanctions part of `process_sanctions_violence.py` |
| `Create_violence_data.ipynb` | `clean_ucdp_ov.py` + violence part of `process_sanctions_violence.py` |
| `create_gdelt_data.ipynb` | `clean_gdelt.py` + GDELT part of `process_sanctions_violence.py` |
| `data/data_clean/final.csv` | `data/clean/base/base.csv` |
| `data/data_clean/country_year_sanctions.csv` | `data/processed/sanctions_violence/intermediate/country_year_sanctions.csv` |
| `data/data_clean/country_year_sanctions_coflict.csv` | `data/processed/sanctions_violence/intermediate/country_year_sanctions_conflict.csv` |
| `data/data_clean/country_year_sanctions_coflict_gdelt.csv` | `data/processed/sanctions_violence/sanctions_violence_panel.csv` |
| `data/orphans/*.csv`, `base_cross.csv` | `data/processed/sanctions_violence/checks/` |
| `R files/unit_root_testing.Rmd`, `R files/1st_var.Rmd` | `empirics/scripts/01_unit_root_tests.Rmd`, `02_panel_var.Rmd` (only the data path changed) |
| `01_data_prep.ipynb`, `pandas_check.ipynb`, `Data_merge.ipynb`, `Untitled.Rmd`, `Regressions_Conflict.Rmd`, `main.py`, root CSV copies, duplicate codebook | `archive/` |

The scripts are a 1:1 refactor of the notebooks: only the data-changing cells were kept, and the logic is unchanged.
