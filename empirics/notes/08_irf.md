# 08 — Impulse responses

Script: `empirics/scripts/08_irf.R` · Output: `results/tables/irf_summary.md`, `irf_results.csv`,
`results/figures/fig12_irf_no_controls.png`, `fig12_irf_with_controls.png`, `fig13_cumulative_irf.png`.
Run of 2026-10-21 19:38, 199 country-cluster bootstrap draws.

**What an IRF adds.** Table 1 tells whether lags matter. An IRF combines both equations to trace the *total*
path after a one-unit shock, including feedback (sanction → violence → more sanctions → …). This follows
Jaeger & Paserman Section V.

**Identification (the key choice).** Annual data cannot tell which came first within a year, so three
assumptions are shown:

- **simple** (JP fn. 12): neither variable affects the other in the same year; shocks are taken as they are.
- **Cholesky, sanctions first:** a new sanction can change violence in the same year (not the reverse).
- **Cholesky, violence first:** violence can trigger sanctions in the same year (not the reverse). For a
  sanction shock this equals "simple".

## Cumulative responses after 10 years (95% bootstrap band; * = excludes 0)

**Sanction shock → violence**

| Spec | Controls | Simple / violence first | Sanctions first |
|---|---|---|---|
| Incidence | no | 0.004 [−0.069, 0.083] | 0.118 [0.016, 0.223] * |
| Incidence | yes | **−0.077 [−0.154, −0.006] *** | 0.031 [−0.072, 0.124] |
| Levels | no | −0.107 [−0.256, 0.061] | 0.239 [0.061, 0.477] * |
| Levels | yes | −0.150 [−0.300, 0.006] | 0.177 [0.023, 0.355] * |

**Violence shock → sanctions**

| Spec | Controls | Simple / sanctions first | Violence first |
|---|---|---|---|
| Incidence | no | 0.159 [0.066, 0.260] * | 0.257 [0.145, 0.369] * |
| Incidence | yes | 0.120 [0.038, 0.210] * | 0.214 [0.106, 0.306] * |
| Levels | no | 0.137 [0.021, 0.260] * | 0.385 [0.240, 0.541] * |
| Levels | yes | 0.091 [−0.016, 0.217] | 0.339 [0.189, 0.495] * |

## Meaning

- **Violence → sanctions is robust:** significant in 11 of 12 versions. A conflict year leads to about
  0.12–0.26 additional new-sanction years over the following decade. If violence may trigger sanctions in the
  same year, the response roughly doubles; most of the reaction is fast.
- **Sanctions → violence depends on the timing assumption:**
  - *Without* a same-year effect, the cumulative response is negative in three of four versions and
    significant for incidence with controls: −0.077 [−0.154, −0.006], i.e. about 0.08 fewer conflict-years over
    10 years (mean conflict probability 0.23 per year). Levels with controls: −0.150 [−0.300, 0.006], just
    insignificant. Without controls, incidence: ≈ 0.
  - *With* a same-year effect (sanctions first), it is positive and significant (+0.12 to +0.24). The
    contemporaneous residual correlation is positive (sanctions and violence spike together, see script 07).
    This ordering attributes it to the sanction.
  - Neither ordering is credible on its own: senders often react to escalation within weeks, while sanctions
    could also provoke escalation. The truth lies between the bands; annual data cannot settle it.
- **Jackknife (dashed lines in fig12):** same shape, slower decay (higher persistence after the bias
  correction).
- **Bootstrap:** resamples whole states, so the bands account for within-state dependence. It does not
  correct for the weak cross-state dependence found in script 06.

## Bottom line

Senders react to violence robustly. Sanctions are followed by a small, significant reduction in conflict
(incidence with controls) if sanctions have no same-year effect on violence; if they do, the cumulative effect is
positive. Which ordering is right cannot be settled with annual data. Monthly or event-level data (e.g. GDELT or UCDP GED
dates against sanction announcement dates) would be the way to break this identification problem.
