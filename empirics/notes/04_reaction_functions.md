# 04 — Reaction functions and Granger tests (Tables 1 and 2)

Script: `empirics/scripts/04_reaction_functions.R` · Output: `results/tables/table1_reaction_functions.md`,
`table2_lag_grid.md`, `table1_*.csv`, `table2_lag_grid.csv`. Run of 2026-10-21 19:35.

**What is estimated.** The panel analogue of Jaeger & Paserman (2008), Table 1. There are two equations; together
they form a bivariate VAR(2):

    Sender eq.:   S_it = Σ_k a_k S_i,t-k + Σ_k b_k V_i,t-k + controls_t-1 + state FE + year FE + e
    Violence eq.: V_it = Σ_k c_k V_i,t-k + Σ_k d_k S_i,t-k + controls_t-1 + state FE + year FE + u

- S = new sanction (0/1) or number of new cases.
- V = conflict (≥ 25 deaths, 0/1) or log(1 + deaths per 100k).
- Controls: sanction stock, GDP growth, democracy, ex-Yugoslavia dummy, all at t−1.
- FE-OLS, standard errors clustered by state.

A "reaction function" is one of these equations: how each side reacts to the other's past. It is not an
impulse response; those come from combining both equations (script 08).

---

## Table 1: Granger tests (χ²(2), p-value; sum of the two lag coefficients)

| Direction | Spec | With controls (OLS) | No controls (OLS) | With controls (jackknife) | No controls (jackknife) |
|---|---|---|---|---|---|
| Sanctions → violence | incidence | **7.27 (0.026)**, −0.035 | 5.01 (0.082), +0.002 | **7.87 (0.020)** | 4.85 (0.088) |
| Sanctions → violence | levels | **8.08 (0.018)**, −0.050 | **7.14 (0.028)**, −0.035 | **7.84 (0.020)** | **6.18 (0.045)** |
| Violence → sanctions | incidence | **6.11 (0.047)**, +0.055 | **9.86 (0.007)**, +0.070 | 3.80 (0.149) | **11.29 (0.004)** |
| Violence → sanctions | levels | 2.79 (0.248), +0.030 | **7.30 (0.026)**, +0.045 | 3.77 (0.152) | **22.78 (< 0.001)** |

### Sanctions → violence

- Significant in most versions, and the effect sits at **t−2**: a new sanction is followed two years later by
  a 3.5 pp lower conflict probability (mean 0.23) and about 4.4% fewer deaths per capita. The t−1 coefficient
  is zero.
- With controls the sum is negative (−0.035 / −0.050). Without controls the incidence sum is ≈ 0 because the
  t−1 coefficient turns slightly positive (+0.020). The *sign* is therefore fragile, even though the joint
  test usually rejects.
- The jackknife does not change this direction: the bias correction mainly affects own persistence.

### Violence → sanctions

- Significant without controls (OLS and jackknife). The sum is positive: a conflict year raises the
  probability of a new sanction by about 3–4 pp at each of t−1 and t−2 (mean 0.11–0.12).
- With controls it weakens, mainly because of **GDP growth**: in the control-by-control check, GDP growth alone
  pushes the levels test to p = 0.226. Conflict lowers growth, and low growth predicts sanctions, so growth is
  plausibly a *bad control* (a channel of violence rather than a confounder). This is decision D8: the
  proposed main specification is FE only, with controls as robustness.
- The jackknife without controls makes it stronger (22.78 in levels). With controls it is insignificant
  (p ≈ 0.15).

### Other coefficients worth noting

- **Own persistence:** violence 0.35 + 0.13 (incidence, OLS) → 0.45 + 0.21 (jackknife). The Nickell bias is
  visible. New sanctions 0.13 at t−1: senders follow up.
- **GDP growth:** lowers both sanctions and violence. **Democracy:** fewer new sanctions. **Ex-Yugoslavia:**
  +10 pp new sanctions (ICTY-era cases).
- **Sample:** with controls 174 states / 4,913 obs (microstates lack V-Dem). Without controls 197 / 5,538.
  Part of the difference between panels A and B is sample, not controls.

## Table 2: lag grid (Jaeger & Paserman Table 2 analogue)

Granger χ² for every combination of 1–3 own lags and 1–3 lags of the other variable, on a common sample.

- **Violence → sanctions:** significant at 5% in all 9 combinations without controls (OLS: p ≤ 0.027). With
  controls: incidence significant with 1–2 violence lags (p ≈ 0.01–0.03; with 3 lags p ≈ 0.07); levels only with
  one violence lag (p ≈ 0.048). BIC prefers
  (1, 1). Senders react to *last year's* violence.
- **Sanctions → violence:** with one sanction lag never significant at 5% (with controls p = 0.36–0.99). With two or more lags,
  significant in most cells. The effect is a *t−2 effect*, which a 1-lag model misses entirely. BIC prefers
  (3, 1) for incidence but (3, 2) for levels.
- **Robustness to own lags:** adding own lags (rows 2→3) barely moves either test, so the sender-equation
  residual autocorrelation from script 06 does not drive the results.

## Interpretation so far

- Senders respond predictably to violence. Violence responds to sanctions with a two-year delay: with controls,
  a significant **reduction** in conflict (−3.5 pp at t−2; sums −0.035 / −0.050, p = 0.026 / 0.018), robust to the
  jackknife and GMM. Without controls the incidence sum is ≈ 0, so the reduction is conditional on the
  controls (see decision D8).
- Annual data cannot separate within-year ordering. If sanctions are imposed *in response to* escalation
  within the same year, the contemporaneous correlation is positive and the lagged effect may partly be
  reversion. Scripts 07 and 08 deal with this.
