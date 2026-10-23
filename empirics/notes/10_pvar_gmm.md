# 10 — GMM panel VAR (robustness to the Nickell bias)

Script: `empirics/scripts/10_pvar_gmm.R` · Output: `results/tables/gmm_pvar.md`, `gmm_granger.csv`,
`gmm_coefficients.csv`, `gmm_lag_selection.csv`. Run of 2026-10-21 19:36.

**Why GMM.** FE-OLS with a lagged dependent variable is biased by O(1/T) (Nickell). GMM avoids this by
transforming away the fixed effects and instrumenting the lagged variables with deeper lags. This is the
"canonical" panel VAR of Holtz-Eakin, Newey & Rosen (1988) and Love & Zicchino (2006).

- Implementation: `panelvar::pvargmm`.
- Forward orthogonal deviations, two-step, collapsed instruments (lags 2–5).
- Variables demeaned by year (equivalent to year effects).

The OLS jackknife and GMM are two different solutions to the same problem. If both agree with OLS, the bias is
not driving the results.

## A. Granger tests by estimator (χ²(2), p)

| Direction | Spec | Controls | OLS | Jackknife | GMM |
|---|---|---|---|---|---|
| S → V | incidence | no | 5.01 (0.082) | 4.85 (0.088) | 6.17 (0.046) |
| S → V | incidence | yes | 7.27 (0.026) | 7.87 (0.020) | 6.25 (0.044) |
| S → V | levels | no | 7.14 (0.028) | 6.18 (0.045) | 7.48 (0.024) |
| S → V | levels | yes | 8.08 (0.018) | 7.84 (0.020) | **11.52 (0.003)** |
| V → S | incidence | no | 9.86 (0.007) | 11.29 (0.004) | 0.56 (0.758) |
| V → S | incidence | yes | 6.22 (0.045) | 3.93 (0.140) | 0.52 (0.772) |
| V → S | levels | no | 7.30 (0.026) | 22.78 (< 0.001) | 7.77 (0.021) |
| V → S | levels | yes | 2.82 (0.244) | 3.86 (0.145) | 2.95 (0.229) |

**Meaning.**
- **Sanctions → violence:** GMM confirms OLS in all four versions, with similar negative sums (−0.03 to
  −0.07). This direction is robust to the estimator.
- **Violence → sanctions, levels:** GMM agrees with OLS (significant without controls, not with).
- **Violence → sanctions, incidence:** GMM finds nothing (p ≈ 0.76), but see the Hansen test below: the
  incidence models are the ones where the instruments are questionable. With a binary, rarely switching
  conflict variable, deeper lags are weak predictors of the differenced lag (weak instruments), so GMM loses
  precision exactly here.

**Caveat on the GMM Wald test:** `panelvar` stores only the standard errors of the coefficients, not their
covariance. The χ² ignores the covariance between the two lag coefficients and is approximate.

## B. Diagnostics

| Spec | Controls | Moment conditions | Hansen J (df 8) | Largest root |
|---|---|---|---|---|
| Incidence | no | 16 | 16.50, **p = 0.036** | 0.574 |
| Incidence | yes | 22 | 14.70, p = 0.065 | 0.557 |
| Levels | no | 16 | 7.60, p = 0.473 | 0.689 |
| Levels | yes | 22 | 8.31, p = 0.404 | 0.671 |

- **Hansen J:**
  - Levels: instruments are not rejected and the p-values are not suspiciously close to 1.
  - Incidence: rejection without controls, borderline with controls. The GMM incidence results are the least
    trustworthy, which is the main reason not to read the GMM V → S incidence null as a contradiction of OLS.
- **Instrument count:** 16–22 moment conditions against 174–197 states. Well below the rule of thumb, with no
  instrument proliferation.
- **Stability:** all roots < 1, close to OLS.

## C. Lag length (Andrews–Lu MMSC)

MMSC-BIC prefers 1 lag in both specifications, and MMSC-AIC prefers 3 (incidence) / 2 (levels). As in script 03,
the criteria disagree mildly. We keep 2 lags for comparability with OLS; the S → V effect at t−2 would be
lost with 1 lag (see the Table 2 note).

## Bottom line

GMM confirms the sanctions → violence pattern and the levels results for violence → sanctions. Where GMM
disagrees (incidence V → S), its own specification test flags a problem. Overall, the Nickell bias does not
drive the Table 1 conclusions.
