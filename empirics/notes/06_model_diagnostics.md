# 06 — Model diagnostics: what they mean and what we found

Script: `empirics/scripts/06_model_diagnostics.R` · Output: `results/tables/model_diagnostics.md`, `diag_residual_autocorrelation.csv`,
`diag_cross_section_dependence.csv`, `diag_stability.csv`. Run of 2026-10-21 19:36. Test mechanics:
`tests_explained.md`, sections 5–7.

**Purpose.** Script 03 checked the *data*. This script checks the *estimated model* (Table 1, VAR(2), OLS with
state and year FE). The three questions:

1. Are two lags enough (M1)?
2. Are the standard errors credible (M2)?
3. Do shocks die out (M3)?

**Verdict in one line.**
- The violence equation is clean.
- The sender equation has a tiny leftover autocorrelation at lag 2.
- There is weak cross-state correlation, enough to justify a Driscoll–Kraay robustness check, not enough to
  change the model.
- Every VAR is stable.

---

## M1. Residual serial correlation — are the lags enough?

**Logic.** If the VAR captured all dynamics, this year's residual should not be predictable from last year's.
Fixed-effects residuals are demeaned within each state, which mechanically creates a correlation of
−1/(T − 1) ≈ −0.037. The null is that value, not zero.

| Equation | Lag 1: ρ (p) | Lag 2: ρ (p) |
|---|---|---|
| Violence, incidence, controls | −0.017 (0.50) | −0.025 (0.69) |
| Violence, levels, controls | 0.003 (0.43) | −0.050 (0.77) |
| Sender, incidence, controls | −0.005 (0.08) | −0.001 (**0.042**) |
| Sender, levels, controls | −0.001 (0.11) | −0.001 (**0.046**) |

(Without controls: same pattern; violence p = 0.53–0.80, sender lag 2 p = 0.042–0.044.)

**Meaning.**
- **Violence equation:** residual correlations are indistinguishable from the null. Two lags of violence and of
  sanctions capture the dynamics of conflict, and the Granger test for sanctions → violence is not distorted
  by omitted dynamics.
- **Sender equation:** the lag-2 residual correlation is about −0.001 instead of −0.037. The test rejects at 5%
  (p ≈ 0.04), so there is a little positive autocorrelation left over. In size it is negligible:
  ρ − ρ₀ ≈ 0.036 explains about 0.1% of the residual variance. Plausible source: sanction episodes in which
  senders follow up a few years later (D3: P(new | new last year) = 0.30).
- **What would fix it:** a third own lag in the sender equation. The lag grid (script 04, rows (3, ·)) already
  shows that adding own lags leaves the violence → sanctions test practically unchanged (e.g. 7.17 → 7.09
  incidence with controls).
- **Why it matters for GMM:** instruments are lags 2–5 of the variables. Serial correlation in the errors
  would make them invalid. For the levels specification, Hansen J does not reject (script 10). For incidence
  without controls it does (p = 0.036), which fits this small sender-equation problem.

## M2. Cross-sectional dependence — Pesaran CD test

**Logic.** Clustering by state allows any correlation within a state over time but assumes states are
independent of each other. Year effects remove shocks that hit all states *equally*; CD detects shocks that hit
states *unequally* (a sanction wave concentrated on one region, a regional war).

**Read the "outcome varies" rows.** For states whose outcome never changes (100 never-in-conflict states), the
residual is just minus the year effects, the same series for all of them, so they are mechanically correlated.
That produces the huge "all states" CD values (81–171) and says nothing about common shocks.

| Equation | States (outcome varies) | Mean correlation | CD | p |
|---|---|---|---|---|
| Violence, incidence, controls | 89 | −0.007 | −2.27 | 0.023 |
| Violence, incidence, no controls | 89 | −0.005 | −1.70 | 0.089 |
| Violence, levels, controls | 113 | 0.018 | 8.22 | < 0.001 |
| Violence, levels, no controls | 113 | 0.017 | 7.71 | < 0.001 |
| Sender, incidence, controls | 155 | 0.010 | 5.71 | < 0.001 |
| Sender, incidence, no controls | 165 | 0.020 | 12.40 | < 0.001 |
| Sender, levels, controls | 155 | 0.020 | 11.57 | < 0.001 |
| Sender, levels, no controls | 165 | 0.029 | 18.15 | < 0.001 |

**Meaning.**
- **Violence incidence:** essentially no dependence. The mean correlation is −0.007 and the test is borderline.
- **Violence levels and sender equations:** statistically significant but small. The mean pairwise
  correlation is 0.01–0.03 (for comparison, the mean *absolute* correlation of ~0.2 is what pure noise with
  T ≈ 30 produces). The CD test is very powerful with thousands of pairs, so small correlations reject.
- **Interpretation:** senders act in waves. The EU and US sanction several states in the same year, e.g. after
  2011 (Arab Spring) or 2014 (Russia/Ukraine-related designations), and these waves hit some states more than
  others.
- **Consequence:**
  - Clustered standard errors may be somewhat too small, especially in the sender equation.
  - Two checks are planned: Driscoll–Kraay standard errors (robust to cross-sectional dependence, script 09)
    and the country-cluster bootstrap already used for the IRFs (script 08).
  - A common-factor model (Nazlioglu & Karul 2024) is not needed at these magnitudes.
- **Controls:** adding controls lowers the dependence in the sender equation (0.020 → 0.010 for incidence).
  Part of the common component comes from economic conditions (GDP growth).

## M3. Stability — do shocks die out?

Largest modulus of the companion-matrix eigenvalues (stable if < 1):

| Specification | Controls | OLS | Jackknife | GMM |
|---|---|---|---|---|
| Incidence | no | 0.600 | 0.745 | 0.574 |
| Incidence | yes | 0.574 | 0.725 | 0.557 |
| Levels | no | 0.685 | 0.804 | 0.689 |
| Levels | yes | 0.673 | 0.804 | 0.671 |

**Meaning.**
- Every VAR is stable, so impulse responses converge and cumulative responses are finite.
- The largest root is essentially the persistence of violence. A root of 0.67 means a shock has decayed to
  about 0.67¹⁰ ≈ 2% after ten years.
- **The jackknife is higher (0.73–0.80):** this is the Nickell bias correction at work. OLS understates
  persistence, and the jackknife restores it. The jackknife IRFs (dashed in fig12) therefore decay more slowly.
- **OLS and GMM agree closely.** GMM has no Nickell bias, but it estimates persistence from instruments, which
  is noisier. Their agreement suggests the bias at T ≈ 30 is moderate.

---

## Summary of what to do with these results

| Finding | Action |
|---|---|
| Violence equation clean | Keep VAR(2) as baseline |
| Sender equation lag-2 autocorrelation (tiny) | Mention; robustness with 3 own lags already in Table 2 |
| Weak cross-sectional dependence | Driscoll–Kraay SE in script 09; bootstrap in 08 |
| All roots < 1 | IRFs in 08 are valid |
