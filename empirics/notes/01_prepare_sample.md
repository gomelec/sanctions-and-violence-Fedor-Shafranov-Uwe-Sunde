# 01 — Estimation sample

Script: `empirics/scripts/01_prepare_sample.R` · Output: analysis panel + `results/tables/sample_summary.csv`,
`sample_exclusions.csv`, `sample_coverage.csv`.

**Window.** 1989–2019: UCDP violence data start in 1989 and the GSDB/controls coverage is complete through 2019.
Years from 1986 are kept only so that lags exist. With two lags, the first usable regression year is 1991.

**States.** 197 states and 5,932 state-years. Four states are excluded because they have fewer than 10 complete
years in the window: GDR (2), Czechoslovakia (4), South Sudan (9), South Yemen (2). Too short series add
almost nothing and make the half-panel jackknife unstable.

**Main variables (means over the 5,932 state-years).**

| Variable | Mean | Note |
|---|---|---|
| New sanction (0/1) | 0.108 | ~11% of state-years see at least one new case |
| New sanction cases | 0.164 | max 10 in one year |
| Conflict, ≥ 25 deaths (0/1) | 0.205 | |
| log(1 + deaths per 100k) | 0.268 | deaths per 100k are extremely skewed (mean 4.5, SD 165: Rwanda 1994) |

**Things to keep in mind.**
- About 90–100 states are never in conflict (90 in the sample summary; 100 have a constant conflict series in
  1989–2019 in script 03) and 31 are never newly sanctioned. They stay in (see `03_data_diagnostics.md`, D1).
- 723 state-years lack controls, mostly microstates without V-Dem. Specifications with controls therefore use
  174 states, not 197. Comparisons "with vs without controls" mix a control effect and a sample effect.
- The log transformation tames the outliers. The 0/1 version is the Jaeger & Paserman-style robustness with
  respect to the threshold.
