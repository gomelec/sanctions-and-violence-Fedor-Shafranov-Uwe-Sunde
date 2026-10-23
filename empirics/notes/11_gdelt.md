# 11 — GDELT instead of UCDP violence (robustness R12)

Script: `empirics/scripts/11_gdelt.R` · Output: `results/tables/gdelt_results.md`, `gdelt_*.csv`,
`results/figures/fig14_gdelt_cumulative_irf.png`, `fig15_gdelt_response_functions.png` (JP Fig. 2 with GDELT;
changed from the LP-DiD figure on 2026-10-22, LP-DiD now in script 12). Numbers confirmed by your master run of 2026-10-22 16:45 (99 bootstrap draws).

**Measures.** `gdelt_lev` = assault + fight + mass-violence events in % of all GDELT events in the state-year;
`gdelt_inc` = 1 if above the state's own 1979–2021 median. Windows: 1991–2019 (Table 1 years) and 1981–2021.

**Validation (1989–2019).** Correlation with UCDP log deaths 0.61 pooled, 0.47 within states. But a UCDP
conflict year is above the GDELT median only 64% of the time (46% for peaceful years): the median split labels
half of all years "violent" and is a noisy incidence measure.

**Granger tests, OLS, with controls, 1991–2019 (sum of lags, p):**

| Direction | UCDP | GDELT |
|---|---|---|
| Sanctions → violence, incidence | −0.035 (0.026) | −0.032 (0.146) |
| Sanctions → violence, levels | −0.050 (0.018) | +0.027 (0.027) |
| Violence → sanctions, incidence | +0.055 (0.047) | −0.012 (0.487) |
| Violence → sanctions, levels | +0.030 (0.248) | +0.004 (0.528) |

- **Sanctions → violence.** Incidence: same sign and size as UCDP, not significant. Levels: positive and
  significant (without controls +0.143, p = 0.004); the LP-DiD extension (12) shows the violent share up
  by 0.8–1.1 pp in the years after a sanction, with flat pre-trends. Full period 1981–2021: insignificant.
  Reading: possibly fewer full-scale conflicts (UCDP) but more reported low-level violence (GDELT).
- **Violence → sanctions.** Not found with GDELT (OLS p = 0.27–0.83; flat IRFs; only
  the jackknife in levels without controls rejects, with tiny coefficients). Given the weak incidence measure,
  this is not a decisive contradiction of UCDP. (LP-DiD for GDELT onsets, script 12: non-zero pre-trends.)
- **Response functions (JP Fig. 2, two-way FE):** after a new sanction the violent share is up 0.5–0.7 pp in the
  sanction year and the year after, then fades (as with UCDP, violence peaks around the sanction). Around an
  above-median GDELT violence year, the sanction probability is up only 1.5–2 pp in the year before and the year
  itself (UCDP conflict year: +3–5 pp), with nothing afterwards — consistent with the null Granger tests.
- **Thin coverage** (dropping state-years with < 100 GDELT events) changes nothing.
- **Stationarity:** both GDELT measures stationary (Maddala–Wu, Choi p < 0.001); persistence 0.36 (incidence)
  and 0.51 (levels), Nickell-corrected. All VARs stable (largest root ≤ 0.81).

**Next step.** A stricter GDELT incidence definition (D6 alternatives: top quartile, any mass-violence event)
before drawing conclusions from the GDELT incidence results.
