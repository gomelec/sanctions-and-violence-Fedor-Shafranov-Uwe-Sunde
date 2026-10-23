# Literature: paper-by-paper summaries

Reading notes for the sanctions–violence panel-VAR project (`empirics/ANALYSIS_PLAN.md`). One entry per paper:
why it matters for this project, its priority, and — for applied papers — sample, data and methods.

**Last updated:** 2026-10-21 · **Papers covered:** 16 (14 in `papers/`, 2 only in `docs/papers/`)

## How this file is maintained

- Drop new PDFs into `papers/` and ask Claude to "update the paper summaries in `papers/README.md`".
- The **file index** at the bottom lists every PDF already summarised. An update compares the folder with that index,
  reads only the new PDFs, adds one entry each (same template), places it in the overview table, and revises the
  "Implications for the project" section if the new paper changes anything. Existing entries are not rewritten
  unless a paper is replaced by a newer version.
- "Read depth" in the index says how much of each paper was read (full text vs. abstract, introduction and the
  sections on data, method and results), so gaps are visible.

**Priority legend**

| Priority | Meaning |
|---|---|
| **A** | Must cite and directly shapes the design, estimation or positioning |
| **B** | Should cite; used for a robustness check, an alternative estimator or a specific argument |
| **C** | Background or context; cite if space allows |

---

## Overview

| # | Paper | Type | Priority | Why it matters, in one line |
|---|---|---|---|---|
| 1 | Jaeger & Paserman (2008), *AER* | applied (template) | **A** | The design we replicate: two reaction functions, Granger tests, incidence vs levels, response functions |
| 2 | Yalcin, Felbermayr et al. (2024), GSDB Release 4, WIFO WP | data | **A** | Source and documentation of our sanctions data; new vs existing cases (validated our flow variables) |
| 3 | Juodis, Karavias & Sarafidis (2021), *Empirical Economics* | method | **A** | Panel Granger test with Nickell-bias correction (half-panel jackknife); built for N ≈ T panels like ours |
| 4 | Dizaji & Murshed (2024), *World Development* | applied | **A** | Closest prior work: cross-country panel VAR of arms-import shocks and internal conflict; positioning |
| 5 | Dube, Girardi, Jordà & Taylor (2023, rev. 2025), NBER WP | method | **A** | Local-projection DiD event study with clean controls and non-absorbing treatment; fits `new_sanction` |
| 6 | de Chaisemartin & D'Haultfœuille (2020, v14 2026), arXiv/NBER | method | **A** | Fixed-effects and panel LP regressions with on/off treatments can be biased; the critique a referee will raise |
| 7 | Mei, Sheng & Shi (2023, v5 2026), arXiv | method | **A** | Panel LP with fixed effects has Nickell bias even without lagged outcomes; split-panel jackknife fix; rule of thumb fits our panel |
| 8 | Chen & Roth (2024), *QJE* | method | **A** | log(1 + y) / asinh effects with zeros are unit-dependent; why we read signs, not magnitudes, from log specs |
| 9 | Abrigo & Love (2016), *Stata Journal* | method / software | **B** | Standard GMM panel-VAR workflow (FOD, MMSC lag selection, Granger, stability, IRF, FEVD); our GMM robustness check |
| 10 | Xiao, Juodis, Karavias, Sarafidis & Ditzen (2023), *Stata Journal* | software | **B** | Implementation of #3 (`xtgrangert`): BIC lag choice, heteroskedasticity, bootstrap for cross-sectional dependence; balanced panels only |
| 11 | Plagborg-Møller & Wolf (2021), *Econometrica* | method | **B** | LPs and VARs estimate the same impulse responses; justifies LP as a robustness check of VAR IRFs |
| 12 | Li, Plagborg-Møller & Wolf (2024), *J. Econometrics* | method | **B** | Bias–variance trade-off: VAR main, LP robustness; may differ in panels |
| 13 | Nazlioglu & Karul (2024), *Empirical Economics* | method | **B/C** | Heterogeneous panel Granger test with common factors (cross-sectional dependence); works best with T > N |
| 14 | Dizaji & Farzanegan (2023), *Defence and Peace Economics* | applied | **C** | Methodological template of #4 (same 47 countries, same OLS PVAR); no conflict variable |
| 15 | Urtuzuastigui & Koren (2024), *World Development* | applied | **B** | Sanctions on armed actors → violence against civilians (resource substitution); prior for one-sided violence split |
| 16 | Stork (2020), Uppsala BA thesis | applied | **C** | Rebel-group panel: UN targeted sanctions → more one-sided violence; context only |

---

## Implications for the project (cross-paper)

1. **Nickell bias is not negligible for us.** With N ≈ 170 states and T ≈ 31 years (N/T ≈ 5.5), plain fixed-effects
   estimates and Wald tests can be distorted, including for the cross-lag (Granger) coefficients (#3, #7). Abrigo &
   Love (#9) cite Judson & Owen (1999): significant bias even at T = 30. This corrects the plan's earlier statement
   that the bias is small: **add the half-panel jackknife correction** to the FE-OLS reaction functions and use the
   JKS test (#3) as the main panel Granger test. Mei et al. (#7) recommend the jackknife for T ≥ 30 and N/T ≤ 10,
   which our panel meets. Their closest case (Cerra & Saxena: 175 countries, T = 35) had the largest bias (≈ 75%).
2. **Balanced panel needed for JKS / `xtgrangert`** (#3, #10): run it on the balanced sub-panel (states existing in
   every year of the window), report the main FE-OLS results on the full panel. Mei et al. (#7, appendix B.2)
   discuss unbalanced panels, time FE and two-way clustering for the jackknife.
3. **Event-study side** (the analogue of JP's Figure 2): LP-DiD with clean controls (#5) is the natural modern
   version for a non-absorbing binary event like `new_sanction`; dCDH (#6) explains why naive FE / panel-LP
   versions can be biased. Dube et al.'s democracy application (175 countries, 1960–2010, non-absorbing binary
   treatment, lagged outcomes as controls) is the closest worked example.
4. **IRFs:** VAR as main estimator, LP as robustness (#11, #12); in panels LP may be relatively more attractive (#12).
5. **Zeros:** keep the incidence specification and PPML; do not interpret log(1 + y) coefficients as percentages (#8).
6. **Positioning against #4:** they have no sanctions data (arms-import shocks), an expert risk index instead of
   fatalities (they avoid UCDP for "insufficient variation"), 48 selected countries, no year effects, no Nickell-bias
   treatment, no Granger tests and 68% bands. Our project addresses all of these.

---

## Entries

### 1. Jaeger & Paserman (2008) — The template · Priority A

**Citation:** Jaeger, D. A., & Paserman, M. D. (2008). The Cycle of Violence? An Empirical Analysis of Fatalities in
the Palestinian-Israeli Conflict. *American Economic Review*, 98(4), 1591–1604.
**File:** `Jaeger-CycleViolenceEmpirical-2008.pdf` (also in `docs/papers/`)

**Why it matters.** The design this project replicates in a panel. Every table and figure has a counterpart in
`empirics/ANALYSIS_PLAN.md`.

| | |
|---|---|
| Sample | One conflict; daily data, 29 Sep 2000 – 15 Jan 2005; 3,244 Palestinian and 994 Israeli fatalities (B'Tselem) |
| Variables | Daily fatalities on each side: incidence (any fatality, 0/1) and levels (counts) |
| Method | Bivariate VAR with 14 lags; equation-by-equation OLS with heteroskedasticity-robust SEs (linear probability model for incidence); controls: day-of-week, 7 conflict-phase dummies, separation-barrier length |
| Main test | Granger causality: χ² test that all 14 lags of the other side are zero |
| Other outputs | Nonparametric response functions (Fig. 2A/2B, raw conditional means, 60 days); lag-structure grid 4/7/14/21 days (Table 2); time aggregation weekly/biweekly/monthly, levels only because incidence has little variation at low frequency (Table 3); checkpoint-closure proxy for Israeli vigilance (Table 4); alternative "intended violence" measures (Appendix II); probit and zero-inflated Poisson checks (fn. 3); cumulative long-run IRFs from the levels VAR (Section V, fn. 12, no same-day response assumed) |
| Identification | Granger ≠ causality; argue that fatalities have a large random component and that plausible forward-looking behaviour would bias *against* their finding |
| Findings | Palestinian fatalities Granger-cause Israeli lethal responses (χ² 43.5, p < 0.001 incidence; 24.3, p = 0.042 levels), not the reverse; long run: one Israeli fatality → +2.19 Palestinian fatalities, one Palestinian fatality → +0.25 Israeli fatalities |
| No unit-root tests | Daily fatality series treated as stationary |

**Note on naming:** JP name a response function after the *trigger* ("Israeli response function" = Palestinian
fatalities after an Israeli fatality). A re-analysis (Asali, Abu-Qarn & Beenstock 2017, *JAE*; not in the folder)
disputes the result with nonlinear VARs suited to zero-heavy fatality data.

### 2. GSDB Release 4 (2024) — Sanctions data · Priority A

**Citation:** Yalcin, E., Felbermayr, G., Kariem, H., Kirilakha, A., Kwon, O., Syropoulos, C., & Yotov, Y. V. (2024).
The Global Sanctions Data Base – Release 4: The Heterogeneous Effects of the Sanctions on Russia. WIFO Working Paper 681/2024.
**File:** `The Global Sanctions Data Base – Release 4- The Heterogeneous Effects of the Sanctions on Russia.pdf`

**Why it matters.** Documentation of our sanctions source. Its Fig. 1 (new vs existing cases per year) and Fig. 6(b)
(new vs existing sanctions on Russia 2014–2023) were used to validate our flow variables (`data/README.md`, S11:
Russia 2022 = 25 new / 38 in force, exact match).

| | |
|---|---|
| Coverage | 1,547 sanction cases, 1950–2023; case-level and dyadic (sender × target × year) versions; available on request (GSDB@drexel.edu) |
| Content | Six sanction types (trade — with complete/partial import/export —, financial, travel, arms, military assistance, other); nine objectives (policy change, regime destabilization, territorial conflict, prevent war, end war, terrorism, human rights, democracy, other); success scores (total, partial, negotiated settlement, failed, ongoing) |
| Sources | UNSC resolutions; US OFAC, State, Commerce; EU Council common positions; national sources and news; cross-checked with SIPRI, HSE, TIES, EUSANCT |
| Facts used | Active cases rose 31% (2021), 25% (2022), 23% (2023); few sanctions are lifted; the US drives new cases |
| Application | Structural gravity model of trade (UN Comtrade, 1960–2023) for the sanctions on Russia: negative but small average effects, heterogeneous across senders; lower trade costs with China, India, Turkey |

### 3. Juodis, Karavias & Sarafidis (2021) — Bias-corrected panel Granger test · Priority A

**Citation:** Juodis, A., Karavias, Y., & Sarafidis, V. (2021). A homogeneous approach to testing for Granger
non-causality in heterogeneous panels. *Empirical Economics*, 60, 93–112.
**File:** `Juodis, Karavias & Sarafidis, "A homogeneous approach ...", Empirical Economics.pdf`

**Why it matters.** The main panel Granger test for our two reaction functions.

- **Idea:** under H0 (no Granger causality) the cross-lag coefficients are zero for every unit, hence homogeneous, so
  they can be estimated by one pooled fixed-effects-type estimator, while intercepts and own-lag coefficients may
  differ by unit (they are partialled out unit by unit).
- **Bias:** the pooled estimator has Nickell bias of the same order as its standard error when N and T grow together;
  corrected with the half-panel jackknife (Dhaene & Jochmans 2015): β̃ = 2β̂ − (β̂_first half + β̂_second half)/2;
  Wald test on β̃, χ²(lags). Valid for N/T³ → 0.
- **Simulations:** N ∈ {50, 100, 200}, T ∈ {20, 50, 100}; good size; Dumitrescu–Hurlin can be badly over-sized when
  T ≪ N and has lower power.
- **Caveats for us:** balanced panels only; T > 1 + lags per unit; power requires "sufficiently many" units with
  non-zero effects (relevant when many states never have violence); stationarity assumed (rules out unit roots).
- **Application:** 350 US banks, 2006Q1–2019Q4 (56 quarters); profitability ↔ cost efficiency.

### 4. Dizaji & Murshed (2024) — Closest prior work · Priority A

**Citation:** Dizaji, S. F., & Murshed, S. M. (2024). External arms embargoes and their implications for government
expenditure, democracy and internal conflict. *World Development*, 173, 106410.
**File:** `External arms embargoes and their implications for government expenditure, democracy and internal conflict.pdf`

**Why it matters.** The only cross-country panel VAR linking (a proxy for) sanctions to internal conflict. Must be
cited and distinguished.

| | |
|---|---|
| Sample | 48 developing countries (list in appendix: e.g. Algeria, Brazil, China, Colombia, Iran, Myanmar, Nigeria, Sudan, Syria, Venezuela, Yemen; includes Hungary, Poland, Latvia, Lithuania), 1990–2017, annual. No selection rule stated; the companion paper (#14) uses the same list minus Syria "according to data availability". Many listed states were never under an arms embargo, and most embargoed states are missing (e.g. Iraq, Libya, Liberia, Sierra Leone, DRC, Somalia, Afghanistan) |
| Sanctions measure | **None directly.** "Arms embargo" = a one-s.d. negative shock to arms imports / GDP (SIPRI TIV); asymmetric version min(0, Δ arms imports / GDP) |
| Violence measure | ICRG internal conflict index (0–12, higher = less risk); also ethnic and religious tensions, external conflict. UCDP/PRIO not used "as there is insufficient variation in that data set for our purposes" (fn. 6) |
| Other variables | Military expenditure / GDP, armed forces / labour force, military in politics (ICRG), government stability (ICRG), Polity2, V-Dem v9 indices, education, health and total government spending, GDP per capita |
| Method | "Unrestricted" panel VAR in levels with country effects, estimated by OLS (argue OLS is consistent because only lags enter); no GMM, no discussion of Nickell bias, no year effects |
| Specification checks | Panel unit roots: LLC, IPS, Fisher-ADF/PP, CIPS (all I(0)); 2 lags by SIC/HQ; stability (roots inside unit circle) |
| Identification | Cholesky with arms imports first ("most exogenous"); generalized IRFs as ordering check |
| Inference | IRFs with 68% bands (±1 s.d.); no Granger tests |
| Findings | Falling arms imports → lower military spending, better democracy scores, higher social spending and GDP per capita, but **more internal conflict and ethnic tension** (ICRG) |

### 5. Dube, Girardi, Jordà & Taylor (2023, revised 2025) — LP-DiD · Priority A

**Citation:** Dube, A., Girardi, D., Jordà, Ò., & Taylor, A. M. (2023). A Local Projections Approach to
Difference-in-Differences. NBER Working Paper 31184 (revised May 2025). Stata: `lpdid`.
**File:** `Dube, Girardi, Jordà & Taylor, "A Local Projections Approach to Difference-in-Differences Event Studies.pdf`

**Why it matters.** A modern, regression-based event study for a binary event that can switch on and off — the
best upgrade of JP's nonparametric response function for `new_sanction`.

- **Method:** LP of y(t+h) − y(t−1) on the treatment change, estimated only on newly treated units and "clean
  controls" (units whose treatment status has not changed in a window of L periods), with time effects. Avoids the
  negative-weighting bias of two-way FE; variance-weighted, equally weighted (reweighted ATT) and pooled versions;
  covariates by regression adjustment; equivalent to stacked regressions and close to Callaway–Sant'Anna,
  Sun–Abraham, Borusyak et al. in simulations.
- **Non-absorbing treatment:** estimators for first-time entry, and for any treatment event under an "effect
  stabilization" assumption.
- **Applications:** (i) banking deregulation and the labour share (US states); (ii) democratization and GDP per
  capita, replicating Acemoglu et al. (2019): 175 countries, 1960–2010, non-absorbing binary democracy indicator,
  lagged GDP as controls for the pre-democratization dip; treated = democratize at t with no change in the previous
  L years; controls = non-democracies for at least L years. Shows ANRR's semiparametric LP implicitly assumes
  effects stabilize after one year.
- **For us:** treated = state-years with a new sanction and no new sanction in the previous L years; clean
  controls = states without a new sanction in the window; outcome = violence; control for lagged violence (the
  sender reaction makes selection on past violence likely).

### 6. de Chaisemartin & D'Haultfœuille — Intertemporal treatment effects · Priority A

**Citation:** de Chaisemartin, C., & D'Haultfœuille, X. Difference-in-Differences Estimators of Intertemporal
Treatment Effects. arXiv 2007.04267 (v14, May 2026); NBER WP 29873. Stata: `did_multiplegt_dyn`. Journal version not
confirmed — check before citing.
**File:** `Difference-in-Differences Estimators of Intertemporal Treatment Effects.pdf`

**Why it matters.** States the problem with fixed-effects regressions on lagged treatments, which is what our
reaction functions are.

- **Setting:** panel; treatment may be non-binary, non-absorbing, and lagged treatments may affect the outcome.
- **Estimators:** compare a unit's outcome change from the period before its first treatment change with units
  whose treatment has not changed yet *and* had the same initial treatment; placebo tests for pre-trends;
  normalized versions average the effects of current and lagged treatments.
- **Key negative results:** two-way FE regressions (including distributed-lag regressions) can be biased with
  heterogeneous effects; **a panel local-projection regression can be biased, even of the wrong sign, with
  homogeneous effects** (contamination by effects of other lags/exposure lengths).
- **Application:** banking deregulation in US states in the 1990s (Favara & Imbs 2015): very persistent effects on
  credit and house prices, unlike the original panel-LP results whose long-run coefficients put negative total
  weight on the effects.
- **For us:** acknowledge that FE-OLS reaction functions estimate weighted averages of heterogeneous effects;
  use LP-DiD (#5) / `did_multiplegt_dyn` as robustness for the violence response to new sanctions.

### 7. Mei, Sheng & Shi (2023, v5 2026) — Nickell bias in panel LP · Priority A

**Citation:** Mei, Z., Sheng, L., & Shi, Z. Nickell Bias in Panel Local Projection: Financial Crises Are Worse Than
You Think. arXiv 2302.13455 (v5, January 2026). R and Stata code linked in the paper.
**File:** `Mei, Sheng & Shi, "Nickell Bias in Panel Local Projection- ...".pdf`

**Why it matters.** Any panel LP with country fixed effects (our IRF robustness, LP-DiD) inherits Nickell bias even
without lagged outcomes, biasing towards zero and invalidating t-tests.

- **Results:** bias rises with horizon and with the persistence of the regressor; inference worse with larger N and
  smaller T. Fix: split-panel jackknife β̂_SPJ = 2β̂_FE − (β̂_FE,first half + β̂_FE,second half)/2, clustered SEs;
  valid for N/T³ → 0. **Rule of thumb: T ≥ 30 and N/T ≤ 10.** Appendix B.2: two-way FE, two-way clustering,
  Driscoll–Kraay, unbalanced panels.
- **Applications (revisited):** Romer & Romer (2017), 24 advanced countries 1967–2012 (semiannual); Baron et al.
  (2021), 46 countries 1870–2016; Mian et al. (2017), 30 countries 1960–2012; Cerra & Saxena (2008), 175 countries
  1965–2000. FE underestimates peak output losses by 16–75%; largest gap for Cerra & Saxena (N = 175, T = 35) — the
  panel shape closest to ours.

### 8. Chen & Roth (2024) — Logs with zeros · Priority A

**Citation:** Chen, J., & Roth, J. (2024). Logs with Zeros? Some Problems and Solutions. *Quarterly Journal of
Economics*, 139(2), 891–936.
**File:** `Chen & Roth (2024), "Logs with zeros? Some problems and solutions.pdf`

**Why it matters.** 72% of our state-years have zero deaths; we use log(1 + deaths per 100,000).

- Effects on log(1 + y) or asinh(y) are **not percentage effects**: if treatment moves the extensive margin, the
  estimate can take any magnitude by rescaling the units of y.
- Trilemma: no parameter is simultaneously an average of individual effects, unit-invariant and point-identified.
- Alternatives: (i) effects in levels expressed as a percentage (Poisson / PPML); (ii) explicitly value the
  extensive margin; (iii) separate extensive- and intensive-margin effects (e.g. Lee bounds).
- **For us:** interpret signs and Granger tests from the log spec; magnitudes from incidence and PPML (plan, R3).

### 9. Abrigo & Love (2016) — Panel VAR in Stata · Priority B

**Citation:** Abrigo, M. R. M., & Love, I. (2016). Estimation of panel vector autoregression in Stata. *Stata
Journal*, 16(3), 778–804. Commands: `pvar`, `pvarsoc`, `pvargranger`, `pvarstable`, `pvarirf`, `pvarfevd`.
**File:** `abrigo-love-2016-estimation-of-panel-vector-autoregression-in-stata.pdf`

**Why it matters.** The reference workflow for the GMM panel-VAR robustness check (R8; R package `panelvar` follows the same logic).

- Homogeneous panel VAR with unit fixed effects and optional exogenous covariates.
- Notes that FE-OLS is biased with lagged dependent variables (Nickell 1981) and cites Judson & Owen (1999):
  significant bias even at T = 30.
- GMM: forward orthogonal deviations (Helmert) preferred to first differences in unbalanced panels (lose fewer
  observations); lagged levels as instruments; "GMM-style" instruments with zeros for missing values; Roodman (2009):
  report the number of instruments and check robustness to reducing it; weak instruments near a unit root.
- Model selection by Andrews–Lu (2001) MMSC (BIC, AIC, HQIC based on Hansen's J); Granger Wald tests; stability
  (companion-matrix eigenvalues); Cholesky IRFs with Monte Carlo bands; FEVD.
- Illustrated with standard Stata datasets (no substantive application).

### 10. Xiao, Juodis, Karavias, Sarafidis & Ditzen (2023) — `xtgrangert` · Priority B

**Citation:** Xiao, J., Juodis, A., Karavias, Y., Sarafidis, V., & Ditzen, J. (2023). Improved tests for Granger
noncausality in panel data. *Stata Journal*, 23(1), 230–242.
**File:** `Xiao, Juodis, Karavias, Sarafidis & Ditzen, "Improved tests ...", Stata Journal 23(1), 2023.pdf`

**Why it matters.** Implementation details for #3 (to be replicated in R).

- Same number of lags for y and x; lag choice by BIC (`maxlags`); `het` for cross-sectional heteroskedasticity;
  pairs bootstrap (Gonçalves & Kaffo 2015) for weak cross-sectional dependence; `sum` reports the sum of the
  feedback coefficients; multivariate x allowed.
- **The panel must be balanced.**
- Application: US banks, N = 450, T = 56; inefficiency predicts profitability, not asset quality.

### 11. Plagborg-Møller & Wolf (2021) — LP and VAR estimate the same IRFs · Priority B

**Citation:** Plagborg-Møller, M., & Wolf, C. K. (2021). Local Projections and VARs Estimate the Same Impulse
Responses. *Econometrica*, 89(2), 955–980.
**File:** `Plagborg-Møller & Wolf (2021), "Local Projections and VARs ...", Econometrica.pdf`

**Why it matters.** Justifies reporting LP impulse responses as a robustness check of the VAR IRFs.

- In population, with unrestricted lags, LPs and VARs estimate the same impulse responses; they are two dimension-
  reduction techniques with different finite-sample properties.
- Any VAR identification scheme can be done with LPs and vice versa; an instrument can be ordered first in a
  recursive VAR; linear VARs are as robust to nonlinearities as linear LPs.
- Theoretical paper; no substantive application.

### 12. Li, Plagborg-Møller & Wolf (2024) — LP vs VAR in practice · Priority B

**Citation:** Li, D., Plagborg-Møller, M., & Wolf, C. K. (2024). Local projections vs. VARs: Lessons from thousands
of DGPs. *Journal of Econometrics*, 244(2), 105722.
**File:** `Li, Plagborg-Møller & Wolf, "Local projections vs. VARs- Lessons from thousands of DGPs".pdf`

**Why it matters.** Guidance on which IRF estimator to make the main one.

- Simulation across thousands of DGPs fitted to US macro data (Stock–Watson dynamic factor model).
- LP: lower bias, much higher variance at intermediate and long horizons. Bias-corrected LP preferred only if one
  cares almost exclusively about bias; otherwise VARs (Bayesian VARs at short and long horizons, least-squares VARs
  at intermediate and long horizons). LP and VAR agree approximately at horizons ≤ the VAR lag length.
- Authors conjecture the trade-off may favour LP more in **panel** settings (large N reduces variance).
- **For us:** VAR-based IRFs main, LP (with jackknife, #7) as robustness — consistent with the plan.

### 13. Nazlioglu & Karul (2024) — Granger tests with cross-sectional dependence · Priority B/C

**Citation:** Nazlioglu, S., & Karul, C. (2024). Testing for Granger causality in heterogeneous panels with
cross-sectional dependence. *Empirical Economics*, 67, 1541–1579.
**File:** `Nazlioglu & Karul, "Testing for Granger causality ...", Empirical Economics 67, 2024.pdf`

**Why it matters.** A heterogeneous alternative that explicitly models common shocks (sanction waves, global
conflict trends) as unobserved factors.

- Method: panel VAR with common factors; de-factor the data with PANIC (Bai & Ng 2004); unit-by-unit lag-augmented
  VAR (Toda–Yamamoto) Wald tests; combine p-values (meta-analysis / Fisher-type).
- Simulations: mild size distortions when N is not smaller than T (disappear as T grows); better than
  Emirmahmutoglu–Kose and Dumitrescu–Hurlin bootstrap tests as T grows; robust to differing unit-root/cointegration
  properties across units.
- Application: exports ↔ GDP growth, 20 OECD countries, 1996Q1–2019Q4 (two-way causality in the panel; little in
  most EU countries individually).
- **Caveat for us:** N > T and many units with constant series (never violent) make unit-by-unit VARs infeasible for
  a large part of the panel → lower priority than #3.

### 14. Dizaji & Farzanegan (2023) — Democracy and militarization · Priority C

**Citation:** Dizaji, S. F., & Farzanegan, M. R. (2023). Democracy and Militarization in Developing Countries: A Panel
Vector Autoregressive Analysis. *Defence and Peace Economics*, 34(3), 272–292.
**File:** `Democracy and Militarization in Developing Countries  A Panel Vector Autoregressive Analysis.pdf`

**Why it matters.** Same team, data and method as #4; shows the template that #4 follows. No conflict variable.

| | |
|---|---|
| Sample | 47 developing countries (= #4 without Syria), 1990–2017, annual; chosen "according to data availability"; authors argue selection bias is small (69% of world population, 59% of armed forces, 67% of arms imports in 2017) |
| Variables | Arms imports / GDP, military and non-military expenditure / GDP, armed forces / labour force, government revenue / GDP (WDI, IMF WEO), military in politics (ICRG), Polity2, V-Dem v9 indices |
| Method | OLS panel VAR in levels with country effects; LLC, IPS, Fisher, CIPS unit-root tests; Pesaran CD test rejects cross-sectional independence; lags by information criteria (2 and 3 as robustness); Cholesky + generalized IRFs; 68% bands; FEVD |
| Findings | Better democracy → lower military, higher non-military spending; positive military-spending shocks lower democracy indices |

### 15. Urtuzuastigui & Koren (2024) — Targeted sanctions and violence against civilians · Priority B

**Citation:** Urtuzuastigui, J., & Koren, O. (2024). Targeted sanctions, resource substitution, and violence against
civilians: Localized evidence from African states. *World Development*, 179, 106606.
**File:** `docs/papers/1-s2.0-S0305750X24000767-main.pdf`

**Why it matters.** Micro evidence for an escalation mechanism (resource substitution) and for one-sided violence
as the outcome most likely to respond — supports our split by violence type (R5) and arms/objective splits (R7).

| | |
|---|---|
| Sample | Africa, 0.5° grid cells (AfroGrid), monthly, Jan 2006 – Dec 2013; only crop-producing cells (SPAM): 6,460 cells × 96 months = 620,160 cell-months |
| Sanctions | UN Security Council targeted sanctions on state and non-state actors (Targeted Sanctions Consortium, Biersteker et al. 2018), matched to UCDP GED actors by month: sanctioned, pre-sanctioned (same actors before the sanction) and unsanctioned |
| Violence | UCDP GED one-sided violence against civilians, aggregated to cell-month, separately by actor type; very rare (means ≈ 0.001) |
| Treatment intensity | Cash-crop cells × lagged vegetation productivity (NDVI, MODIS) |
| Method | Linear FE models by OLS on log(1 + attacks) with a lagged dependent variable, country and month FE, country × year FE in full models; count / zero-inflated models in the appendix; Somalia (al-Shabaab, charcoal ban 2012) case study |
| Findings | Cash-crop productivity predicts violence against civilians by **sanctioned** actors, not by unsanctioned or pre-sanctioned ones |

### 16. Stork (2020) — Sanctions and rebel violence against civilians · Priority C

**Citation:** Stork, E. (2020). Pressuring Rebels: A Quantitative Study on Sanctions' Effects on Violence Against
Civilians. Thesis, Peace and Conflict Studies C, Uppsala University (supervisor C. Bara). (File name says 2025; the
title page is dated January 2020.)
**File:** `docs/papers/upsula sacntions and violence 2025.pdf`

**Why it matters.** Context for the one-sided-violence mechanism; student thesis, not a citable main source.

| | |
|---|---|
| Sample | Rebel groups in intrastate conflicts, 1992–2014 (UCDP Battle-Related Deaths v19.1; dyad years filled between first and last active year; groups fighting several governments and Syria excluded): 231 groups, 1,201 group-years |
| Sanctions | UN targeted sanctions on the rebel group (Targeted Sanctions Consortium, 1991–2013): ordinal 0–4 count of arms embargo, asset freeze, resource ban; lagged one year; dichotomous version as a check |
| Violence | UCDP GED civilian deaths by the group per year (mean ≈ 33, max 1,171, many zeros), logged |
| Method | Bivariate and multivariate OLS on group-years; robustness including sanctions on governments |
| Findings | Sanctions on rebel groups are followed by more one-sided violence |

---

## Cited in the plan but not yet in the folder

Judson & Owen (1999, *Economics Letters*) · Love & Zicchino (2006, *QREF*) · Holtz-Eakin, Newey & Rosen (1988,
*Econometrica*) · Dumitrescu & Hurlin (2012, *Economic Modelling*) · Dhaene & Jochmans (2015, *REStud*) · Hultman &
Peksen (2017, *JCR*) · Meierrieks & Gries (2013, *JPR*) · Bove & Elia (Afghanistan panel VAR) · Asali, Abu-Qarn &
Beenstock (2017, *JAE*) · Acemoglu, Naidu, Restrepo & Robinson (2019, *JPE*).

---

## File index

| File | Folder | Entry | Added | Read depth |
|---|---|---|---|---|
| `Jaeger-CycleViolenceEmpirical-2008.pdf` | `papers/`, `docs/papers/` (duplicate) | 1 | 2026-10-21 | full |
| `The Global Sanctions Data Base – Release 4- The Heterogeneous Effects of the Sanctions on Russia.pdf` | `papers/` | 2 | 2026-10-21 | sections 1–2 (data) and overview of section 3 |
| `Juodis, Karavias & Sarafidis, "A homogeneous approach ...", Empirical Economics.pdf` | `papers/` | 3 | 2026-10-21 | sections 1–4 (method, simulation design), application summary |
| `External arms embargoes and their implications for government expenditure, democracy and internal conflict.pdf` | `papers/` | 4 | 2026-10-21 | full |
| `Dube, Girardi, Jordà & Taylor, "A Local Projections Approach to Difference-in-Differences Event Studies.pdf` | `papers/` | 5 | 2026-10-21 | introduction, section 4.2 (non-absorbing), section 6.2 (democracy application) |
| `Difference-in-Differences Estimators of Intertemporal Treatment Effects.pdf` | `papers/` | 6 | 2026-10-21 | abstract, introduction (incl. LP and application summary) |
| `Mei, Sheng & Shi, "Nickell Bias in Panel Local Projection- ...".pdf` | `papers/` | 7 | 2026-10-21 | introduction, section 2.3 (SPJ, rule of thumb), application summary |
| `Chen & Roth (2024), "Logs with zeros? Some problems and solutions.pdf` | `papers/` | 8 | 2026-10-21 | abstract, introduction |
| `abrigo-love-2016-estimation-of-panel-vector-autoregression-in-stata.pdf` | `papers/` | 9 | 2026-10-21 | sections 1–3 (model, GMM, MMSC, Granger, IRF, FEVD), command options |
| `Xiao, Juodis, Karavias, Sarafidis & Ditzen, "Improved tests ...", Stata Journal 23(1), 2023.pdf` | `papers/` | 10 | 2026-10-21 | sections 1–3 |
| `Plagborg-Møller & Wolf (2021), "Local Projections and VARs ...", Econometrica.pdf` | `papers/` | 11 | 2026-10-21 | abstract, introduction |
| `Li, Plagborg-Møller & Wolf, "Local projections vs. VARs- Lessons from thousands of DGPs".pdf` | `papers/` | 12 | 2026-10-21 | abstract, introduction, conclusion |
| `Nazlioglu & Karul, "Testing for Granger causality ...", Empirical Economics 67, 2024.pdf` | `papers/` | 13 | 2026-10-21 | abstract, introduction, model setup, application summary |
| `Democracy and Militarization in Developing Countries  A Panel Vector Autoregressive Analysis.pdf` | `papers/` | 14 | 2026-10-21 | data, method, notes, appendix |
| `1-s2.0-S0305750X24000767-main.pdf` | `docs/papers/` | 15 | 2026-10-21 | introduction, research design |
| `upsula sacntions and violence 2025.pdf` | `docs/papers/` | 16 | 2026-10-21 | abstract, research design |
