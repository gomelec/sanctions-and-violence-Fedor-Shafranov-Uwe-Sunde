# 09 — Robustness checks

Script: `empirics/scripts/09_robustness.R` · Output: `results/tables/robustness_nonlinear.md`, `robustness_nonlinear.csv`.
Part 1 (R3) written 2026-10-22; further parts (controls one at a time, Driscoll–Kraay, splits, time aggregation,
anticipation proxy) to follow.

## R3. Logit and PPML (Jaeger & Paserman, footnote 3)

**Why.** The main models are linear: linear probability models for incidence, OLS on log(1 + deaths per 100k) for
levels. With many zeros, a linear probability model can predict outside [0, 1], and log(1 + y) coefficients have no
percentage interpretation (Chen & Roth 2024). The nonlinear versions keep everything else of Table 1 (samples, two
lags, controls, state and year fixed effects as dummies, clustering by state).

- **Logit** for the incidence equations (conflict 0/1, new sanction 0/1). Comparable scale: average partial effect
  ≈ sum of the lag coefficients × mean p(1−p).
- **PPML** (Poisson pseudo-maximum likelihood) for the levels equations, with the *untransformed* outcome: deaths
  per 100,000 (and winsorised at the 99th percentile, 45.6) and the number of new cases. Same right-hand side as
  the levels VAR. Sum of coefficients in log points: exp(sum) − 1 = proportional change.
- States whose outcome never changes drop out (no information with fixed effects): 85–108 states in the conflict
  logit, 61–84 in the deaths PPML, 19–32 in the sender models.

## Results (χ²(2) Granger test, p; comparable sum)

| | Controls | OLS (Table 1) | Logit / PPML |
|---|---|---|---|
| Sanctions → conflict (logit) | yes | 7.27, p = 0.026, sum −0.035 | 6.40, p = 0.041, APE −0.046 |
| | no | 5.01, p = 0.082, sum 0.002 | 5.69, p = 0.058, APE 0.007 |
| Sanctions → deaths (PPML) | yes | 8.08, p = 0.018 | 3.95, p = 0.139, −34% |
| | no | 7.14, p = 0.028 | 2.75, p = 0.253, −25% |
| Sanctions → deaths, winsorised (PPML) | yes | | 12.56, p = 0.002, −16% |
| | no | | 11.99, p = 0.002, −11% |
| Conflict → new sanction (logit) | yes | 6.22, p = 0.045 | 5.67, p = 0.059, APE 0.047 |
| | no | 9.86, p = 0.007 | 10.21, p = 0.006, APE 0.058 |
| log deaths → new cases (PPML) | yes | 2.82, p = 0.244 | 1.60, p = 0.449, +7% |
| | no | 7.30, p = 0.026 | 7.43, p = 0.024, +15% |

**Meaning.**
- The functional form does not drive the results: same signs, same lag pattern (nothing at t−1, negative at t−2 for
  sanctions → violence), similar significance.
- Logit APE with controls (−0.046) is close to the linear-probability estimate (−0.035). Like the OLS incidence
  result, it uses the sanction-stock control in t−1 (see part 4); without controls the APE is +0.007.
- PPML on raw deaths: large negative point estimates but imprecise — a few extreme state-years (Rwanda 1994, etc.)
  dominate the Poisson likelihood. Winsorised, the effect is precise: death rates 11–16% lower two years after a
  new sanction.
- Violence → sanctions: unchanged too — significant without controls, weaker with controls.
- Caveat: fixed-effects logit has an incidental-parameter bias of order 1/T (like the Nickell bias); an analytical
  correction (Fernández-Val & Weidner) is a possible refinement.

## R10. Raw deaths instead of log deaths (Jaeger & Paserman use raw counts)

Linear levels VAR as in Table 1, with deaths per 100,000 instead of log(1 + deaths per 100k) as the violence
variable (outcome and lags): uncapped, capped at p99 (45.6) and at p95 (6.2) of all state-years 1989–2019.

| Granger χ²(2), OLS | Controls | log deaths (Table 1) | Raw | Cap p99 | Cap p95 |
|---|---|---|---|---|---|
| Sanctions → violence | yes | 8.08** (−0.050) | 0.55 (−2.53) | 6.63** (−0.338) | 7.41** (−0.096) |
| | no | 7.14** (−0.035) | 4.18 (+0.56) | 5.68* (−0.186) | 5.82* (−0.067) |
| Violence → sanctions | yes | 2.82 | 292.5*** | 4.58 | 2.01 |
| | no | 7.30** | 323.1*** | 13.94*** | 4.32 |

(sum of the two cross-lag coefficients in brackets: deaths per 100k per new case)

**Meaning.**
- **Uncapped raw deaths are useless:** Rwanda 1994 (12,577 per 100k) dominates. Persistence of violence falls to
  0.17 (0.67 with logs); the sender-equation χ² of ~300 comes from Rwanda alone (2 new cases in 1996, two years after
  the genocide) — without Rwanda it is 4.7 (p = 0.10). This is why the base case uses logs.
- **Capped:** sanctions → violence significant with controls at both caps, negative: −0.34 (p99) / −0.10 (p95)
  deaths per 100k two years after a new case, about 17–24% of the mean of the capped variable.
- Violence → sanctions: significant without controls at p99, weaker otherwise — as in the base case.
- Jackknife versions in `robustness_raw_deaths.csv`, same conclusions.

### R10 dynamics: IRFs and response function with deaths capped at p99

(`robustness_capped_dynamics.md`, figure `fig17_capped_deaths_dynamics.png`; 199 bootstrap draws)

| Cumulative after 10 years | Controls | No same-year effect | Sanctions first | Violence first |
|---|---|---|---|---|
| New case → deaths per 100k | yes | −0.83 [−1.99, 0.21] | +1.08 * | −0.83 |
| | no | −0.47 [−1.59, 0.61] | +1.60 * | −0.47 |
| +1 death per 100k → new cases | yes | 0.007 [−0.002, 0.016] | 0.007 | 0.031 * |
| | no | 0.012 * | 0.012 * | 0.036 * |

- Same signs as the log version; magnitudes now in deaths: one new case → about 0.8 fewer deaths per 100k over ten
  years (≈ half a year's mean of 1.42), but not significant — level dynamics are noisier than the Granger tests.
- Positive if sanctions may affect deaths within the same year (as in the base case).
- Response function: capped deaths up in the year before a sanction, peak +1.8 per 100k in the sanction year (two-way
  FE), back to normal at h = 2 — same shape as with logs.


## Part 4 (decision D8): same-sample control check

(`robustness_controls.md`; master run of 2026-10-23 16:50 — identical to the earlier container test run.)

All versions on one common sample: 4,888 obs., 174 states (all controls available, incl. the stock in t−3).
Cell = sum of the two cross-lag coefficients (Granger p).

| Version | S → V incidence | S → V levels | V → S incidence | V → S levels |
|---|---|---|---|---|
| FE only | −0.000 (0.101) | −0.035 (0.029) | 0.067 (0.011) | 0.043 (0.034) |
| stock t−1 | **−0.032 (0.032)** | −0.041 (0.025) | 0.068 (0.010) | 0.049 (0.020) |
| stock t−3 | −0.000 (0.071) | −0.036 (0.030) | 0.076 (0.003) | 0.050 (0.019) |
| GDP growth | −0.005 (0.126) | −0.044 (0.023) | 0.060 (0.027) | 0.031 (0.226) |
| democracy | −0.005 (0.107) | −0.036 (0.029) | 0.061 (0.023) | 0.037 (0.057) |
| all controls | **−0.036 (0.028)** | −0.050 (0.019) | 0.056 (0.044) | 0.030 (0.248) |
| all, stock t−3 | −0.009 (0.091) | −0.045 (0.023) | 0.063 (0.020) | 0.031 (0.237) |
| FE only, full sample (197 states) | 0.002 (0.082) | −0.035 (0.028) | 0.070 (0.007) | 0.045 (0.026) |

**Meaning.**
- **Sample is not the issue:** FE only on the controls sample ≈ FE only on the full sample.
- **Sanctions → violence, incidence: the negative effect comes from the stock control in t−1.** With it, the t−2
  coefficient is −0.034 and the t−1 coefficient 0; without it (or with the stock dated t−3), t−1 ≈ +0.02,
  t−2 ≈ −0.02 and the sum is 0. The stock in t−1 is mechanically the stock in t−3 plus the new cases of t−1 and t−2,
  i.e. it contains the regressors being tested, so conditioning on it changes what the sanction lags measure (a new
  case "for a given number of cases still in force", which is identified mainly from cases lifted again quickly).
  This is a bad-control problem, not evidence of an effect. The earlier reading "conditional on controls" should
  become "conditional on the stock control, which is mechanical".
- **Sanctions → violence, levels: robust.** −0.035 to −0.050, p ≈ 0.02–0.03 in every version, always from the t−2 lag.
- **Violence → sanctions:** incidence significant in every version; levels lose significance only with GDP growth
  (as found before; likely bad control).
- Consequence for D8: FE only as the main specification; if a stock control is wanted, date it t−3.

## Part 5 (R9): Yugoslavia attribution

(`robustness_yugoslavia.md`; master run of 2026-10-23 16:50.) Ex-Yugoslav states: Yugoslavia/FRY, Serbia, Montenegro, Macedonia,
Croatia, Bosnia-Herzegovina, Kosovo, Slovenia. Main = Table 1 with the new control set (dummy removed).

| | Controls | main | without ex-Yugoslavia | ex-Yugoslavia one cluster |
|---|---|---|---|---|
| S → V incidence | no | 0.002 (p 0.082) | 0.010 (0.138) | 0.002 (0.086) |
| | yes | −0.035 (0.026) | −0.029 (0.071) | −0.035 (0.035) |
| S → V levels | no | −0.035 (0.028) | −0.024 (0.080) | −0.035 (0.069) |
| | yes | −0.050 (0.018) | −0.040 (0.044) | −0.050 (0.042) |
| V → S incidence | no | 0.070 (0.007) | 0.069 (0.010) | 0.070 (0.007) |
| | yes | 0.056 (0.045) | 0.055 (0.052) | 0.056 (0.044) |
| V → S levels | no | 0.045 (0.026) | 0.046 (0.043) | 0.045 (0.025) |
| | yes | 0.031 (0.244) | 0.033 (0.261) | 0.031 (0.242) |

**Meaning.** Violence → sanctions is unaffected. Sanctions → violence is somewhat weaker without the ex-Yugoslav
states (levels, FE only: −0.024, p = 0.080), so part of the levels effect comes from the Yugoslav cases; treating them
as one cluster changes the p-values little. Removing the dummy itself leaves the S → V results unchanged
(7.27, p = 0.026 as before) and moves V → S incidence slightly (6.22 instead of 6.11).
