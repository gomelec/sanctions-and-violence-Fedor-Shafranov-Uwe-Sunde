# Sanctions and Violence

**Do economic sanctions reduce or fuel organized violence, and does violence trigger sanctions?**

![Status](https://img.shields.io/badge/status-work%20in%20progress-orange)
![R](https://img.shields.io/badge/R-4.5-276DC3?logo=r&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.13-3776AB?logo=python&logoColor=white)
![Panel](https://img.shields.io/badge/panel-GW%20states%201950%E2%80%932023-555)

---

## About the project

Sanctions are one of the international community's main non-military responses to armed conflict. Whether they
calm violence (deterrence, incapacitation) or escalate it (retaliation, resource substitution) is still an open
empirical question, and so is the reverse direction: do senders react to violence in a regular, predictable way?

Following the reaction-function approach of Jaeger & Paserman (2008, *AER*), the project estimates a
**panel VAR on a country-year panel** of sanctions and organized violence and tests Granger causality in both
directions:

| Reaction function | Question |
|---|---|
| **Senders** | Does violence in a country predict new sanctions against it? |
| **Violence** | Do new sanctions predict more or less violence afterwards? |

The specification (sanction measure, violence measure, lags, controls, robustness) is fixed in an analysis plan
before estimation. Results will be added here.

## Data

A panel of **Gleditsch–Ward states × years, 1950–2023** (11,989 state-years):

| Domain | Source | Coverage | Main variables |
|---|---|---|---|
| Sanctions | Global Sanctions Data Base (GSDB), release 4 | 1950–2023 | number of cases, any sanction, UN / EU / US / Russia sanctions, sanction types, sender counts |
| Organized violence | UCDP Organized Violence Country-Year, v26.1 | 1989–2023 | battle-related deaths by type (state-based, non-state, one-sided), victims (parties, civilians), per 100,000 |
| Conflict events | GDELT 1.0 (CAMEO roots 17–20) | 1979–2021 | coerce, assault, fight, mass violence (per 1,000 events) |
| Armed conflicts | UCDP/PRIO ACD via `peacesciencer` | 1950–2023 | number of conflicts by type |
| Democracy | V-Dem, Polity via `peacesciencer` | to 2020–23 | `v2x_polyarchy`, `polity2` |
| GDP, population | Anders, Fariss & Markowitz (2020) simulated series via `peacesciencer`; extended with World Bank WDI and UN WPP 2024 (via Our World in Data) | 1950–2023 | `gdp_ext`, `pop_ext` |

Every cleaning and construction decision (e.g. how GSDB's "Yugoslavia" cases are attributed to the successor
republics, how GDELT countries are mapped to historical states) is logged with a reason in
**[`data/README.md`](data/README.md)** and **[`data/README_yugoslavia.md`](data/README_yugoslavia.md)**.

> **Raw data are not included in this repository.** Download them into `data/raw/` as described in
> [`data/raw/README.md`](data/raw/README.md). The GSDB is available on request from the GSDB team
> (gsdb@drexel.edu).

## Reproduce

Requirements: [uv](https://docs.astral.sh/uv/) (Python) and R ≥ 4.5 with `renv`.

```bash
uv sync                                   # Python environment from pyproject.toml + uv.lock
Rscript setup_renv.R                      # R environment from renv.lock
uv run python master.py                   # data pipeline: cleaning + processing
uv run python master.py --stage empirics  # descriptive figures and estimation (R)
uv run python master.py --check           # compare outputs with the frozen baseline
```

Other options: `--stage cleaning|processing|empirics|all`, `--only <step>`, `--skip-r`, `--set-baseline`, `--list`.
Every step writes a log to `data/logs/` (empirics: `empirics/results/logs/`).

## Repository structure

```
data/
  raw/{dataset}/                       as downloaded, never modified (not tracked)
  clean/{dataset}/                     output of the cleaning scripts
  processed/sanctions_violence/        analysis panel: sanctions_violence_panel.csv
  scripts/cleaning/                    clean_{dataset}.py / .R + hand-coded mapping tables (CSV)
  scripts/processing/                  process_sanctions_violence.py
  scripts/checks/                      check_replication.py
empirics/
  scripts/                             00_setup.R (shared setup), descriptives, estimation
  results/                             figures, tables, models
docs/papers/                           reference literature
archive/                               earlier notebooks and the frozen baseline for --check
master.py                              runs the full pipeline
```

## Pipeline

| Step | Script | Output |
|---|---|---|
| clean_base | `data/scripts/cleaning/clean_base.R` | GW state-years with conflict counts, democracy, GDP, population |
| clean_gsdb | `data/scripts/cleaning/clean_gsdb.py` | sanctions received / sent per state-year |
| clean_ucdp_ov | `data/scripts/cleaning/clean_ucdp_ov.py` | organized violence per state-year |
| clean_gdelt | `data/scripts/cleaning/clean_gdelt.py` | GDELT conflict events per state-year |
| clean_population, clean_gdp | `data/scripts/cleaning/clean_population.py`, `clean_gdp.py` | 2020–23 extensions |
| process | `data/scripts/processing/process_sanctions_violence.py` | `data/processed/sanctions_violence/sanctions_violence_panel.csv` |
| descriptives | `empirics/scripts/02_descriptives.R` | `empirics/results/figures/descriptives/` |

## Key references

- Jaeger, D. A., & Paserman, M. D. (2008). The cycle of violence? An empirical analysis of fatalities in the
  Palestinian-Israeli conflict. *American Economic Review*, 98(4), 1591–1604.
- Yalcin, E., Felbermayr, G., Kariem, H., Kirilakha, A., Kwon, O., Syropoulos, C., & Yotov, Y. V. (2024).
  The Global Sanctions Data Base – Release 4. WIFO Working Paper 681/2024.
- Uppsala Conflict Data Program (2026). UCDP Organized Violence Country-Year Dataset, version 26.1.
- Urtuzuastigui, J., & Koren, O. (2024). Targeted sanctions, resource substitution, and violence against
  civilians. *World Development*, 179, 106606.

<details>
<summary>Migration from the original notebooks</summary>

The scripts are a 1:1 refactor of the original notebooks (verified to reproduce the data exactly); later changes
are logged in `data/README.md`.

| Old | New |
|---|---|
| `data_gather_R.ipynb` | `data/scripts/cleaning/clean_base.R` |
| `create_sanction_data.ipynb` | `clean_gsdb.py` + sanctions part of `process_sanctions_violence.py` |
| `Create_violence_data.ipynb` | `clean_ucdp_ov.py` + violence part of `process_sanctions_violence.py` |
| `create_gdelt_data.ipynb` | `clean_gdelt.py` + GDELT part of `process_sanctions_violence.py` |
| `R files/unit_root_testing.Rmd`, `R files/1st_var.Rmd` | `empirics/scripts/01_unit_root_tests.Rmd`, `02_panel_var.Rmd` |
| other notebooks, old outputs | `archive/` |

</details>
