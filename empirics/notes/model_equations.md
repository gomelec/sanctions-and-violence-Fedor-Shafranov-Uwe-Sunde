# Model equations: every estimation written out, with the exact code that runs it

Written 2026-10-23 from the scripts in `empirics/scripts/`. Citations are `file:line` (line numbers of the scripts
as of 23 Oct 2026). Every equation is what the code **does**; where code and plan differ, see section 12.
**If a script changes, the line numbers and this file must be updated.**

How to read each block:

1. **Equation** — written out in full for the lag length actually used ($p = 2$), every symbol defined.
2. **What is estimated / reported** — which numbers come out and how they are computed.
3. **Sample** — exactly which state-years enter.
4. **Code** — the lines that execute it, quoted, with `file:line`.

Indices: $i$ = state (column `gwcode`), $t$ = calendar year (column `yr`).

---

## 0. Variables, lags and samples

### 0.1 Global settings (`00_setup.R`)

| Setting | Value | Code |
|---|---|---|
| estimation window | 1989–2019 | `00_setup.R:24` `SAMPLE_YEARS <- 1989:2019` |
| minimum complete years per state | 10 | `00_setup.R:25` `MIN_OBS <- 10` |
| manually excluded | German Democratic Republic | `00_setup.R:26–29` `MANUAL_EXCLUDE` |
| VAR lag length $p$ | 2 | `00_setup.R:33` `VAR_LAGS <- 2` |
| longest lag anywhere (lag grid) | 3 | `00_setup.R:34` `MAX_LAGS <- 3` |
| conflict threshold | 25 deaths | `00_setup.R:35` `CONFLICT_MIN_DEATHS <- 25` |
| control set | 3 variables | `00_setup.R:39` `CONTROLS <- c("ctrl_stock", "ctrl_gdp_growth", "ctrl_democracy")` (`ex_yugo_1991_2016` removed 2026-10-23) |

### 0.2 The two VAR variables (`01_prepare_sample.R:28–48`)

Raw inputs from `sanctions_violence_panel.csv`:

- $d_{it}$ = `deaths` = `cumulative_total_deaths_in_orgvio_best` — UCDP organized-violence deaths (best estimate)
  (`01_prepare_sample.R:38`).
- $d^{pc}_{it}$ = `deaths_pc` = `cumulative_total_deaths_in_orgvio_best_pc` — the same per 100,000 inhabitants
  (`01_prepare_sample.R:39`).

Constructed:

$$ V^{inc}_{it} = \begin{cases} 1 & \text{if } d_{it} \ge 25 \\ 0 & \text{otherwise} \end{cases} \qquad\qquad V^{lev}_{it} = \ln\big(1 + d^{pc}_{it}\big) $$

$V^{inc}$ is the column `viol_inc`, $V^{lev}$ the column `viol_lev`.

```r
# 01_prepare_sample.R:40-41
viol_inc  = as.integer(deaths >= CONFLICT_MIN_DEATHS),
viol_lev  = log1p(deaths_pc),
```

$$ S^{inc}_{it} = \mathbf 1\big[\text{at least one GSDB case begins against } i \text{ in } t\big], \qquad S^{lev}_{it} = \text{number of GSDB cases beginning against } i \text{ in } t $$

$S^{inc}$ is the column `new_sanction`, $S^{lev}$ the column `n_new_cases`.

(taken as built in the data pipeline, `01_prepare_sample.R:32–33`; construction in `data/README.md` S11).

The two **specifications** used everywhere (`04_reaction_functions.R:42–45`, identical in `08_irf.R:45–48` and `10_pvar_gmm.R:51–54`):

| Specification | sanction variable $S$ | violence variable $V$ |
|---|---|---|
| `incidence` | $S^{inc}$ = `new_sanction` | $V^{inc}$ = `viol_inc` |
| `levels` | $S^{lev}$ = `n_new_cases` | $V^{lev}$ = `viol_lev` |

### 0.3 Controls (`01_prepare_sample.R:44–54`)

$$ g_{it} = \ln y_{it} - \ln y_{i,t-1}, \qquad y_{it} = \text{GDP per capita} $$

$g$ is the column `gdp_growth`; $y$ is the column `gdp`, which 01 sets to `gdp_ext` (= `mrgdppc` up to 2019).

$$ X_{i,t-1} = \big(K_{i,t-1},\ g_{i,t-1},\ D_{i,t-1}\big)' $$

| Symbol | Column in the data | Definition |
|---|---|---|
| $K_{i,t-1}$ | `ctrl_stock` = `n_cases_received` in $t-1$ | GSDB cases in force against $i$ in $t-1$ (stock) |
| $g_{i,t-1}$ | `ctrl_gdp_growth` = `gdp_growth` in $t-1$ | growth of log GDP per capita |
| $D_{i,t-1}$ | `ctrl_democracy` = `v2x_polyarchy` in $t-1$ | V-Dem electoral democracy index |

```r
# 01_prepare_sample.R:44     gdp = gdp_ext,
# 01_prepare_sample.R:51-54
analysis$gdp_growth      <- log(analysis$gdp) - log(lag_by_year(analysis, "gdp", 1))
analysis$ctrl_stock      <- lag_by_year(analysis, "n_cases_received", 1)   # sanction cases in force in t-1
analysis$ctrl_gdp_growth <- lag_by_year(analysis, "gdp_growth", 1)         # GDP per capita growth in t-1
analysis$ctrl_democracy  <- lag_by_year(analysis, "v2x_polyarchy", 1)      # V-Dem polyarchy in t-1
```

Identity (data/README S11): $K_{it} = K_{i,t-1} + \text{new}_{it} + \text{joined}_{it} - \text{lifted}_{it}$, hence
$K_{i,t-1} = K_{i,t-3} + S^{lev}_{i,t-1} + S^{lev}_{i,t-2} + \text{joined}_{i,t-1} + \text{joined}_{i,t-2} - \text{lifted}_{i,t-1} - \text{lifted}_{i,t-2}$.
The stock control therefore contains both sanction lags of the VAR.

### 0.4 How a lag is built (`functions.R:22–39`)

$x_{i,t-k}$ is the value of $x$ for the same state in calendar year $t-k$; if that year is missing, the lag is NA
(no silent use of an older row).

```r
# functions.R:22-28  lag_by_year(): shift the year by +k and merge on (gwcode, yr)
earlier_values[[year]] <- earlier_values[[year]] + k        # value of year t-k now sits in row t
matched <- dplyr::left_join(data[, c(state_id, year)], earlier_values, by = c(state_id, year))
# functions.R:32-39  add_lags(): creates columns <variable>_l1, <variable>_l2, ...
data[[paste0(variable, "_l", k)]] <- lag_by_year(data, variable, k)
```

Names in the coefficient vectors therefore are `viol_inc_l1`, `viol_inc_l2`, `new_sanction_l1`, `new_sanction_l2`
(incidence) and `viol_lev_l1`, `viol_lev_l2`, `n_new_cases_l1`, `n_new_cases_l2` (levels).

### 0.5 Samples

**States** (`01_prepare_sample.R:62–86`): keep state $i$ if it has at least 10 years in 1989–2019 with all four of
`new_sanction`, `n_new_cases`, `viol_inc`, `viol_lev` non-missing, and is not the GDR. Result: 197 states.

```r
# 01_prepare_sample.R:67   complete_years_main = sum(complete.cases(across(all_of(MAIN_VARIABLES)))),
# 01_prepare_sample.R:74-75  too_short <- coverage %>% filter(complete_years_main < MIN_OBS)
# 01_prepare_sample.R:85-86  kept_states <- setdiff(...); analysis_kept <- analysis %>% filter(gwcode %in% kept_states)
```

Years kept in the analysis panel: 1986–2019 (`01_prepare_sample.R:22`: `first_year_kept <- 1989 - MAX_LAGS`);
1986–88 only serve as lags. Flag `in_window` = `yr` ∈ 1989–2019 (`01_prepare_sample.R:56`).

**Estimation sample of a VAR** (`functions.R:181–186`, `build_estimation_sample`; written out again in
`04_reaction_functions.R:66–76`): all state-years with `in_window == TRUE` and **all** of
$S_{it}, V_{it}, S_{i,t-1}, S_{i,t-2}, V_{i,t-1}, V_{i,t-2}$ (and the three controls, if used) non-missing.
The **same** sample is used for both equations. Because UCDP starts in 1989, $V_{i,t-2}$ exists only from
$t = 1991$, so the effective estimation years are 1991–2019.

| | states | observations |
|---|---|---|
| without controls | 197 | 5,538 |
| with controls (V-Dem missing for microstates) | 174 | 4,913 |

---

## 1. Reaction functions = the two equations of the VAR (script 04, Table 1) — base case

### 1.0 The panel VAR: model, assumptions, what each estimator needs

**The model the code assumes.** Stack the two variables as $z_{it} = (V_{it}, S_{it})'$. For every state $i$ and year $t$:

$$ z_{it} = A_1\, z_{i,t-1} + A_2\, z_{i,t-2} + \Gamma\, X_{i,t-1} + \lambda_i + \phi_t + e_{it} $$

| Symbol | Dimension | Meaning | Code |
|---|---|---|---|
| $A_1, A_2$ | 2×2 | lag coefficients (written out below the table) | coefficients `viol_inc_l1` … of the two `lm` fits |
| $\Gamma$ | 2×3 | control coefficients, row 1 $= \gamma'$, row 2 $= \eta'$ | coefficients `ctrl_stock` … |
| $\lambda_i$ | 2×1 | state fixed effects $(\alpha_i, \mu_i)'$ | `factor(gwcode)` |
| $\phi_t$ | 2×1 | year fixed effects $(\tau_t, \delta_t)'$ | `factor(yr)` |
| $e_{it}$ | 2×1 | reduced-form errors $(\varepsilon_{it}, u_{it})'$ | `residuals()` of the two fits |

$$ A_k = \begin{pmatrix} a_k & b_k \\ c_k & d_k \end{pmatrix}, \quad k = 1, 2 $$

Row 1 = violence equation, row 2 = sender equation; column 1 = lagged $V$, column 2 = lagged $S$. So $a_k$ = own lag of violence, $b_k$ = lagged sanctions in the violence equation, $c_k$ = lagged violence in the sender equation, $d_k$ = own lag of sanctions.

**Assumptions** (all estimators below rely on A1–A3; the IRFs also on A4–A6):

- **A1 Homogeneous slopes.** $A_1, A_2, \Gamma$ are the same for all states; states differ only through $\lambda_i$.
- **A2 Sequential exogeneity.** $E\big[e_{it} \mid z_{i,t-1}, z_{i,t-2}, \ldots, X_{i,t-1}, X_{i,t-2}, \ldots, \lambda_i, \phi_t\big] = 0$.
  Past values are predetermined, but today's error may move future values. Lagged dependent variables are
  therefore **not strictly exogenous**, which is the source of the Nickell bias of FE-OLS.
- **A3 No serial correlation.** $E[e_{it}\, e_{is}'] = 0$ for $s \neq t$. Checked in section 10.1.
- **A4 Reduced-form covariance.** $E[e_{it}\, e_{it}'] = \Sigma = \begin{pmatrix} \sigma_{VV} & \sigma_{VS} \\ \sigma_{VS} & \sigma_{SS} \end{pmatrix}$,
  with $\sigma_{VS} \neq 0$ allowed: violence and sanction shocks may be correlated within the year. The clustered
  SEs also allow heteroskedasticity across states.
- **A5 Structural shocks.** $e_{it} = B\,\eta_{it}$, with $\eta_{it} = (\eta^V_{it}, \eta^S_{it})'$ uncorrelated
  "violence" and "sanction" shocks and $B$ the same-year effects. The data identify only $\Sigma = B\,\text{Var}(\eta)\,B'$,
  i.e. 3 numbers for 4 unknowns (2 off-diagonal elements of $B$ with unit diagonal, 2 variances). One restriction
  is needed; the three choices are in section 3.3.
- **A6 Stability.** All eigenvalues of the companion matrix (section 1.6) have modulus < 1.

**Granger non-causality is a zero restriction on $A_1, A_2$:**

- "$S$ does not Granger-cause $V$" ⇔ $b_1 = b_2 = 0$ (the (1,2) elements of $A_1$ and $A_2$).
- "$V$ does not Granger-cause $S$" ⇔ $c_1 = c_2 = 0$ (the (2,1) elements).

**Estimator 1 (base case): FE-OLS, sections 1.2–1.6.** Estimates $\lambda_i, \phi_t$ as dummies, i.e. (by
Frisch–Waugh–Lovell) OLS on two-way-demeaned data. Write $w_{it} = (V_{i,t-1}, V_{i,t-2}, S_{i,t-1}, S_{i,t-2}, X_{i,t-1}')'$
and $\tilde x_{it}$ for the residual of $x_{it}$ on state and year dummies in the estimation sample. Then, for the
violence equation,

$$ \hat\theta_V = \Big(\sum_{i,t} \tilde w_{it}\, \tilde w_{it}'\Big)^{-1} \sum_{i,t} \tilde w_{it}\, \tilde V_{it}, \qquad \theta_V = (a_1, a_2, b_1, b_2, \gamma')' $$

and the same with $\tilde S_{it}$ for the sender equation. Both equations have the same regressors, so
equation-by-equation OLS equals system OLS (SUR gives nothing more).

*Why it is biased in short panels.* The within transformation subtracts the state mean over all years. That mean
contains $e_{i,t-1}, e_{it}, \dots, e_{iT}$, so $\tilde z_{i,t-1}$ is correlated with $\tilde e_{it}$ and A2 is not
enough: $E[\tilde w_{it}\, \tilde e_{it}] \neq 0$. The bias is of order $1/T$ (Nickell 1981); for a pure AR(1) it is
about $-(1+\rho)/(T-1)$ on $\rho$. With $T \approx 29$ it is small but not zero, and it spills over to the cross-lag
coefficients when the regressors are correlated. Two remedies are run: the half-panel jackknife (section 1.5) and
GMM (section 6).

**Estimator 2 (robustness): GMM, section 6.** Removes $\lambda_i$ by forward orthogonal deviations instead of
demeaning, and replaces the endogenous transformed lags by instruments (lagged levels) that are valid under A2–A3.
Consistent for fixed $T$, at the cost of precision and the need for valid, relevant instruments.

| | FE-OLS (04, 08) | Half-panel jackknife (04) | GMM (10) |
|---|---|---|---|
| removes $\lambda_i$ by | state dummies (within) | state dummies, per half | forward orthogonal deviations |
| removes $\phi_t$ by | year dummies | year dummies, per half | subtracting year means first |
| uses for identification | A1–A3 + $T \to \infty$ | A1–A3, bias $O(1/T)$ removed | A1–A3, moment conditions $E[z_{i,t-l}\, e^{\ast}_{it}] = 0$ |
| bias | $O(1/T)$ | $O(1/T^2)$ | none for fixed $T$ (if instruments valid) |
| weak point | Nickell bias | variance, needs stable dynamics across halves | weak instruments (persistent binaries), Hansen test |


### 1.1 Equations

**Violence equation** ("does violence respond to past sanctions?"), for state $i$ and year $t$:

$$ V_{it} \;=\; a_1 V_{i,t-1} + a_2 V_{i,t-2} \;+\; b_1 S_{i,t-1} + b_2 S_{i,t-2} \;+\; \gamma_1 K_{i,t-1} + \gamma_2 g_{i,t-1} + \gamma_3 D_{i,t-1} \;+\; \alpha_i + \tau_t + \varepsilon_{it} $$

**Sender equation** ("do senders respond to past violence?"):

$$ S_{it} \;=\; d_1 S_{i,t-1} + d_2 S_{i,t-2} \;+\; c_1 V_{i,t-1} + c_2 V_{i,t-2} \;+\; \eta_1 K_{i,t-1} + \eta_2 g_{i,t-1} + \eta_3 D_{i,t-1} \;+\; \mu_i + \delta_t + u_{it} $$

- $a_k$: own persistence of violence; $b_k$: **cross-lags tested for sanctions → violence**.
- $d_k$: own persistence of new sanctions; $c_k$: **cross-lags tested for violence → sanctions**.
- $\alpha_i, \mu_i$: state fixed effects (one dummy per `gwcode`); $\tau_t, \delta_t$: year fixed effects
  (one dummy per `yr`); plus an intercept (R drops one dummy of each set).
- "No controls" version: the $\gamma$ / $\eta$ terms are deleted (`04_reaction_functions.R:46`,
  `CONTROL_SETS <- list(with_controls = CONTROLS, no_controls = character(0))`).
- Incidence: $V = V^{inc}, S = S^{inc}$ — both are 0/1, so both equations are **linear probability models**.
  Levels: $V = V^{lev}, S = S^{lev}$.

Together, in matrix form (needed for sections 1.5 and 3):

$$ \begin{pmatrix} V_{it} \\ S_{it} \end{pmatrix} = \begin{pmatrix} a_1 & b_1 \\ c_1 & d_1 \end{pmatrix} \begin{pmatrix} V_{i,t-1} \\ S_{i,t-1} \end{pmatrix} + \begin{pmatrix} a_2 & b_2 \\ c_2 & d_2 \end{pmatrix} \begin{pmatrix} V_{i,t-2} \\ S_{i,t-2} \end{pmatrix} + \begin{pmatrix} \gamma' X_{i,t-1} \\ \eta' X_{i,t-1} \end{pmatrix} + \begin{pmatrix} \alpha_i + \tau_t \\ \mu_i + \delta_t \end{pmatrix} + \begin{pmatrix} \varepsilon_{it} \\ u_{it} \end{pmatrix} $$

i.e. $z_{it} = A_1 z_{i,t-1} + A_2 z_{i,t-2} + \Gamma X_{i,t-1} + \lambda_i + \phi_t + e_{it}$ (section 1.0).

Row 1 of each $A_k$ = violence equation, row 2 = sender equation; column 1 = lagged violence, column 2 = lagged
sanctions.

### 1.2 Estimator: OLS with dummies, equation by equation

Each equation is estimated separately by OLS (identical to system OLS because both equations have the same
regressors). The R formula built by `fit_reaction_function` (`functions.R:61–73`), e.g. violence equation,
incidence, with controls:

```r
viol_inc ~ viol_inc_l1 + viol_inc_l2 + new_sanction_l1 + new_sanction_l2 +
           ctrl_stock + ctrl_gdp_growth + ctrl_democracy +
           factor(gwcode) + factor(yr)
```

```r
# functions.R:63-67
regressors <- c(lag_names(outcome, n_lags),        # own lags
                lag_names(other, n_lags_other),    # lags of the other variable (Granger block)
                controls,
                "factor(gwcode)", "factor(yr)")    # state and year fixed effects
model <- lm(reformulate(regressors, response = outcome), data = data)
```

Called for both equations and both estimators in `04_reaction_functions.R:79–90`:

```r
# 04_reaction_functions.R:79-90
equations <- list(
  violence = list(outcome = violence, other = sanction),   # does violence respond to sanctions?
  sender   = list(outcome = sanction, other = violence)    # do senders respond to violence?
)
...
  OLS       = fit_reaction_function(estimation_sample, outcome, other, N_LAGS, controls),
  jackknife = half_panel_jackknife(estimation_sample, outcome, other, N_LAGS, controls)
```

Loops: specifications (`04_reaction_functions.R:63`) × control sets (`04_reaction_functions.R:68`) × equations → 2 × 2 × 2 = 8 OLS regressions + 8 jackknife
versions.

### 1.3 Standard errors: clustered by state

With $W_{it}$ = all regressors (lags, controls, dummies, intercept), $\hat e_{it}$ the OLS residual,
$n$ observations, $K$ regressors (incl. all dummies), $G$ states:

$$ \hat V \;=\; \frac{G}{G-1}\cdot\frac{n-1}{n-K}\; \Big(\sum_{i,t} W_{it}W_{it}'\Big)^{-1} \Big(\sum_{g=1}^{G} \Big(\sum_{t} W_{gt}\hat e_{gt}\Big)\Big(\sum_{t} W_{gt}\hat e_{gt}\Big)'\Big) \Big(\sum_{i,t} W_{it}W_{it}'\Big)^{-1} $$

(`sandwich::vcovCL` with `type = "HC1"` and its default cluster adjustment $G/(G-1)$.)

```r
# functions.R:69
if (cluster_se) model$vcov_clustered <- sandwich::vcovCL(model, cluster = data$gwcode, type = "HC1")
```

### 1.4 Granger test and sum of the cross-lags (`functions.R:123–132`)

Violence equation: $H_0: b_1 = b_2 = 0$ ("past sanctions do not predict violence").
Sender equation: $H_0: c_1 = c_2 = 0$ ("past violence does not predict new sanctions").

With $\hat\beta = (\hat b_1, \hat b_2)'$ and the corresponding $2\times 2$ block of $\hat V$,
$\hat V_{\beta} = \begin{pmatrix} v_{11} & v_{12} \\ v_{12} & v_{22} \end{pmatrix}$:

$$ W \;=\; \hat\beta' \hat V_{\beta}^{-1} \hat\beta \;=\; \frac{\hat b_1^2 v_{22} - 2\hat b_1 \hat b_2 v_{12} + \hat b_2^2 v_{11}}{v_{11}v_{22} - v_{12}^2} \;\sim\; \chi^2(2) \text{ under } H_0, \qquad p = \Pr\big(\chi^2(2) > W\big) $$

$$ \text{sum} = \hat b_1 + \hat b_2, \qquad \text{se(sum)} = \sqrt{v_{11} + v_{22} + 2 v_{12}} $$

```r
# functions.R:124-131
coefficients <- coef(model)[terms]
covariance   <- model$vcov_clustered[terms, terms, drop = FALSE]
chi2 <- as.numeric(t(coefficients) %*% solve(covariance, coefficients))
... p_value  = pchisq(chi2, df = length(terms), lower.tail = FALSE),
    sum_coef = sum(coefficients),
    sum_se   = sqrt(sum(covariance))
# 04_reaction_functions.R:112   granger_cross <- wald_test(model, lag_names(other, N_LAGS))     # the Granger test
# 04_reaction_functions.R:113   granger_own   <- wald_test(model, lag_names(outcome, N_LAGS))   # own lags, for reference
```

Individual coefficients: $t = \hat\beta_j / \sqrt{\hat V_{jj}}$, $p = 2\Phi(-|t|)$ (`functions.R:139–145`).

### 1.5 Half-panel jackknife (Nickell-bias correction, `functions.R:88–112`)

Split the estimation years into two halves; with 1991–2019 (29 years) the first half has
$\lceil 29/2 \rceil = 15$ years: **H1 = 1991–2005, H2 = 2006–2019**. Re-estimate the same equation (its own state and
year dummies) on each half; lags may come from the other half. For every slope coefficient $\theta$ (lags and
controls, not the dummies):

$$ \tilde\theta \;=\; 2\,\hat\theta_{\text{full}} \;-\; \tfrac12\big(\hat\theta_{H1} + \hat\theta_{H2}\big) $$

The Wald test of 1.4 is applied to $\tilde\theta$ with the **full-sample** clustered covariance $\hat V$.

```r
# functions.R:90-91
years       <- sort(unique(data$yr))
first_years <- years[seq_len(ceiling(length(years) / 2))]
# functions.R:93-97   model_full / model_first / model_second <- fit_reaction_function(...)
# functions.R:100-102
slope_terms <- c(lag_names(outcome, n_lags), lag_names(other, n_lags_other), controls)
jackknife_coefficients <- 2 * coef(model_full)[slope_terms] -
  (coef(model_first)[slope_terms] + coef(model_second)[slope_terms]) / 2
# functions.R:106   vcov_clustered  = model_full$vcov_clustered[slope_terms, slope_terms],
```

### 1.6 Stability: largest root of the companion matrix (`functions.R:151–163`)

$$ F = \begin{pmatrix} A_1 & A_2 \\ I_2 & 0 \end{pmatrix} = \begin{pmatrix} a_1 & b_1 & a_2 & b_2 \\ c_1 & d_1 & c_2 & d_2 \\ 1 & 0 & 0 & 0 \\ 0 & 1 & 0 & 0 \end{pmatrix}, \qquad \text{reported: } \max_j |\lambda_j(F)| \ \ (\text{stable if } < 1) $$

Controls and fixed effects are treated as exogenous (they do not enter $F$).

```r
# functions.R:154-162
lag_matrices <- lapply(seq_len(n_lags), function(k) {
  rbind(c(coef_violence[[paste0(violence, "_l", k)]], coef_violence[[paste0(sanction, "_l", k)]]),
        c(coef_sender[[paste0(violence, "_l", k)]],   coef_sender[[paste0(sanction, "_l", k)]]))
})
companion <- do.call(cbind, lag_matrices)
if (n_lags > 1) companion <- rbind(companion, cbind(diag(2 * (n_lags - 1)), matrix(0, 2 * (n_lags - 1), 2)))
max(Mod(eigen(companion, only.values = TRUE)$values))
# 04_reaction_functions.R:98   var_root <- largest_var_root(coef(estimates$violence[[estimator]]), ...)
```

### 1.7 Lag grid (script 04, Table 2; `04_reaction_functions.R:259–305`)

Same two equations, but with $p_{own} \in \{1,2,3\}$ lags of the dependent variable and $p_{oth} \in \{1,2,3\}$ lags
of the other variable (9 combinations), e.g. violence equation with $(p_{own}, p_{oth}) = (3,1)$:

$$ V_{it} = a_1 V_{i,t-1} + a_2 V_{i,t-2} + a_3 V_{i,t-3} + b_1 S_{i,t-1} + \gamma'X_{i,t-1} + \alpha_i + \tau_t + \varepsilon_{it} $$

Granger test $H_0: b_1 = \dots = b_{p_{oth}} = 0$, $W \sim \chi^2(p_{oth})$. **Sample:** all 9 combinations on one
common sample in which 3 lags of both variables exist (first year 1992), so that BIC is comparable; BIC is the
single-equation `BIC()` of the OLS fit, $\text{BIC} = -2\ln L + K\ln n$. Jackknife halves: 1992–2005 / 2006–2019.

```r
# 04_reaction_functions.R:259   lag_grid <- expand.grid(own_lags = seq_len(MAX_LAGS), other_lags = seq_len(MAX_LAGS))
# 04_reaction_functions.R:265   data_with_lags <- add_lags(analysis, c(sanction, violence), MAX_LAGS)
# 04_reaction_functions.R:269-273  common_sample: in_window and all MAX_LAGS lags non-missing
# 04_reaction_functions.R:285-288
ols_model <- fit_reaction_function(common_sample, outcome, other, own_lags, controls, n_lags_other = other_lags)
jackknife <- half_panel_jackknife(common_sample, outcome, other, own_lags, controls, n_lags_other = other_lags)
# 04_reaction_functions.R:292   granger <- wald_test(model, lag_names(other, other_lags))
# 04_reaction_functions.R:298   bic = BIC(ols_model)
```

---

## 2. Empirical response functions (script 07; JP Figure 2)

### 2.1 Equation

For an event dummy $E_{it} \in \{0,1\}$, an outcome $y$ and each horizon $k = -3, -2, \dots, 8$
(`07_empirical_response.R:35–36`: `LEADS <- 3`, `HORIZON <- 8`), one OLS regression **per $k$**:

$$ y_{i,t+k} \;=\; \kappa_k \;+\; r_k\, E_{it} \;+\; e_{ikt} $$

With a single dummy regressor, OLS gives exactly a difference in means:

$$ \hat r_k \;=\; \overline{y_{i,t+k}}\,\big|_{E_{it}=1} \;-\; \overline{y_{i,t+k}}\,\big|_{E_{it}=0} $$

i.e. the outcome $k$ years after an event year minus the outcome $k$ years after a non-event year
(negative $k$ = before the event). No other regressors, no fixed effects in this regression.

Two versions of $y$:

- **raw**: $y$ as it is.
- **two-way FE**: $y$ replaced by $\tilde y_{it} = y_{it} - \hat\alpha_i - \hat\tau_t$, the residual of an OLS
  regression of $y_{it}$ on state and year dummies, estimated on **all** rows of the analysis panel where $y$ is
  observed (for sanction outcomes this includes 1986–88). $\tilde y$ is computed once, then shifted to $t+k$.

Pairs estimated (`07_empirical_response.R:39–48`):

| `name` | event $E$ | outcome $y$ |
|---|---|---|
| `violence_after_sanction_incidence` | `new_sanction` | `viol_inc` |
| `violence_after_sanction_levels` | `new_sanction` | `viol_lev` |
| `sanctions_after_conflict_incidence` | `viol_inc` | `new_sanction` |
| `sanctions_after_conflict_levels` | `viol_inc` | `n_new_cases` |

### 2.2 Sample, inference

Rows: event year $t$ in 1989–2019 (`in_window`), $E_{it}$ observed, $y_{i,t+k}$ observed. Because the panel ends in
2019 and UCDP starts in 1989, the usable event years shrink with $|k|$. SE clustered by state (HC1, as in 1.3);
band $\hat r_k \pm 1.96\,\widehat{se}$; $p = 2\Phi(-|\hat r_k/\widehat{se}|)$.

### 2.3 Code

```r
# 07_empirical_response.R:57-62  two_way_demean(): residual of y on state and year dummies
rows <- !is.na(data[[variable]])
fit <- lm(reformulate(c("factor(gwcode)", "factor(yr)"), response = variable), data = data[rows, ])
out[rows] <- residuals(fit)
# 07_empirical_response.R:66   value_at <- function(data, variable, k) lag_by_year(data, variable, -k)   # y in t+k
# 07_empirical_response.R:69-75  clustered_estimate(): lm + vcovCL(cluster = gwcode, type = "HC1"), band +-1.96 se
# 07_empirical_response.R:85     data$outcome_fe <- two_way_demean(data, spec$outcome)
# 07_empirical_response.R:87-88  data$outcome_raw_k <- value_at(data, spec$outcome, k)
#                                data$outcome_fe_k  <- value_at(data, "outcome_fe", k)
# 07_empirical_response.R:91     sample_k <- data %>% filter(in_window, !is.na(.data[[y]]), !is.na(.data[[spec$event]]))
# 07_empirical_response.R:93     clustered_estimate(reformulate(spec$event, response = y), sample_k, spec$event)
#   e.g. formula: outcome_fe_k ~ new_sanction
```

---

## 3. Impulse responses (script 08; JP Section V)

### 3.1 Inputs from the two estimated equations

1. Lag matrices $A_1, A_2$ from the OLS coefficients of section 1.1 (or from the jackknife, see 3.6):
   $A_k = \begin{pmatrix} \hat a_k & \hat b_k \\ \hat c_k & \hat d_k \end{pmatrix}$.
2. Residual covariance from the OLS residuals $\hat\varepsilon_{it}$ (violence eq.) and $\hat u_{it}$ (sender eq.),
   same $n$ rows (common sample), divided by $n$ (no degrees-of-freedom correction):

$$ \hat\Sigma = \begin{pmatrix} \sigma_{VV} & \sigma_{VS} \\ \sigma_{VS} & \sigma_{SS} \end{pmatrix}, \quad \sigma_{VV} = \tfrac1n\sum_{i,t}\hat\varepsilon_{it}^2,\;\; \sigma_{SS} = \tfrac1n\sum_{i,t}\hat u_{it}^2,\;\; \sigma_{VS} = \tfrac1n\sum_{i,t}\hat\varepsilon_{it}\hat u_{it} $$

```r
# 08_irf.R:64-68  both equations by OLS (cluster_se = FALSE: no covariance needed here)
violence_model <- fit_reaction_function(data, violence, sanction, N_LAGS, controls, cluster_se = FALSE)
sender_model   <- fit_reaction_function(data, sanction, violence, N_LAGS, controls, cluster_se = FALSE)
coef_violence  <- coef(violence_model);  coef_sender <- coef(sender_model)
# 08_irf.R:71-72
residual_matrix <- cbind(residuals(violence_model), residuals(sender_model))
Sigma <- crossprod(residual_matrix) / nrow(residual_matrix)
```

### 3.2 Moving-average coefficients (`functions.R:196–207`)

$$ \Phi_0 = I_2,\qquad \Phi_1 = A_1,\qquad \Phi_h = \Phi_{h-1}A_1 + \Phi_{h-2}A_2 \quad (h \ge 2),\qquad h = 0,\dots,10 $$

(general form in the code: $\Phi_h = \sum_{j=1}^{\min(h,p)} \Phi_{h-j}A_j$). Horizon `IRF_HORIZON <- 10`
(`08_irf.R:42`).

```r
# functions.R:197-205
A <- lapply(seq_len(n_lags), function(k) rbind(c(a_k, b_k), c(c_k, d_k)))   # built from the named coefficients
Phi[[1]] <- diag(2)
for (h in seq_len(horizon)) {
  Phi[[h + 1]] <- Reduce(`+`, lapply(seq_len(min(h, n_lags)), function(j) Phi[[h - j + 1]] %*% A[[j]]))
}
```

### 3.3 Same-year (impact) matrix $B$ — the identification (`functions.R:228–236`)

Columns of $B$ = the two shocks (column 1 = violence shock, column 2 = sanction shock); rows = the two variables
(row 1 = $V$, row 2 = $S$). Each column is scaled so that the shock moves its **own** variable by exactly 1 in
year 0.

**(a) simple** (JP footnote 12): no same-year effect on the other variable.

$$ B^{simple} = \begin{pmatrix} 1 & 0 \\ 0 & 1 \end{pmatrix} $$

**(b) Cholesky, violence first** (violence may move sanctions in the same year, not the reverse). Lower Cholesky
factor of $\hat\Sigma$ in the order $(V, S)$:

$$ P = \begin{pmatrix} \sqrt{\sigma_{VV}} & 0 \\ \sigma_{VS}/\sqrt{\sigma_{VV}} & \sqrt{\sigma_{SS} - \sigma_{VS}^2/\sigma_{VV}} \end{pmatrix}, \qquad B^{V\text{ first}} = P\,\text{diag}(P)^{-1} = \begin{pmatrix} 1 & 0 \\ \sigma_{VS}/\sigma_{VV} & 1 \end{pmatrix} $$

**(c) Cholesky, sanctions first** (a new sanction may move violence in the same year, not the reverse). Cholesky in
the order $(S, V)$, then put back in the order $(V, S)$ and rescale:

$$ B^{S\text{ first}} = \begin{pmatrix} 1 & \sigma_{VS}/\sigma_{SS} \\ 0 & 1 \end{pmatrix} $$

For a **sanction shock**, (a) and (b) are identical (column 2 is $(0,1)'$ in both).

```r
# functions.R:229-235
unit_scale <- function(P) P %*% diag(1 / diag(P))              # own impact = 1
violence_first <- t(chol(Sigma))                               # chol() returns the upper factor -> transpose
reorder <- c(2, 1)
sanction_first <- t(chol(Sigma[reorder, reorder]))[reorder, reorder]
list(simple = diag(2),
     cholesky_sanction_first = unit_scale(sanction_first),
     cholesky_violence_first = unit_scale(violence_first))
```

### 3.4 Impulse responses and cumulative responses

$$ \Theta_h = \Phi_h B, \qquad \Theta_h[r, s] = \text{response of variable } r \text{ in year } h \text{ to a one-unit shock } s \text{ in year } 0 $$

$$ C_h[r,s] = \sum_{q=0}^{h} \Theta_q[r,s] \qquad\text{(cumulative response; reported at } h = 2, 5, 10\text{)} $$

Worked example, **sanction shock → violence, simple identification** ($\Theta_h[1,2] = \Phi_h[1,2]$):

$$ \Theta_0[1,2] = 0,\qquad \Theta_1[1,2] = b_1,\qquad \Theta_2[1,2] = a_1 b_1 + b_1 d_1 + b_2,\qquad \dots $$

so $C_{10}[1,2]$ = the total change in $V$ summed over years 0–10 after one new sanction, including the feedback
(sanction → violence → further sanctions → …). Under "sanctions first", $\Theta_0[1,2] = \sigma_{VS}/\sigma_{SS}$
and the whole path shifts accordingly.

Shock units: incidence = one new sanction (0 → 1) / one conflict year (0 → 1); levels = one additional new case /
+1 in $\ln(1+d^{pc})$.

```r
# functions.R:215-224  impulse_responses(): theta <- Phi[[h]] %*% impact ; value = theta[response, shock]
# 08_irf.R:74-77
Phi <- var_ma_coefficients(coef_violence, coef_sender, violence, sanction, N_LAGS, IRF_HORIZON)
impacts <- impact_matrices(Sigma)
impulse_responses(Phi, impacts[[identification]])     # for each of the three identifications
# 08_irf.R:113-117  cumulative = cumsum(value) over horizons, by identification x shock x response
```

### 3.5 Bootstrap bands (country-cluster bootstrap; `08_irf.R:81–123`)

For each specification × control set (loops `08_irf.R:94` and `08_irf.R:98`; sample `08_irf.R:100`), with $G$ states in the estimation sample:

1. `set.seed(20261021)` (`08_irf.R:108`).
2. For $b = 1, \dots, B$ with $B$ = `IRF_BOOT_DRAWS` (default 199, `08_irf.R:43`):
   - draw $G$ states **with replacement** from the $G$ states (`08_irf.R:83`);
   - stack all their rows; a state drawn $m$ times appears $m$ times with **different ids** $1,\dots,G$, so it gets
     $m$ separate fixed effects (`08_irf.R:84–85`);
   - re-estimate both equations by OLS on this sample → $A^{(b)}_1, A^{(b)}_2, \hat\Sigma^{(b)}$;
   - recompute $\Theta^{(b)}_h$ and $C^{(b)}_h$ for all three identifications (`08_irf.R:109–111`).
3. Band at each $h$: 2.5% and 97.5% quantiles of $\{\Theta^{(b)}_h\}_b$ and of $\{C^{(b)}_h\}_b$ (R `quantile`,
   type 7) (`08_irf.R:119–123`). Marked "*" if the band excludes 0.

The point estimate is from the original sample (not the bootstrap mean). Bands only for OLS, not for the jackknife.

```r
# 08_irf.R:81-86
resample_states <- function(data) {
  states <- unique(data$gwcode)
  drawn  <- sample(states, length(states), replace = TRUE)
  bind_rows(lapply(seq_along(drawn), function(i) {
    data[data$gwcode == drawn[i], ] %>% mutate(original_gwcode = gwcode, gwcode = i)
  }))
}
# 08_irf.R:109-111
draws <- bind_rows(lapply(seq_len(N_BOOT), function(b) {
  var_responses(resample_states(estimation_sample), sanction, violence, controls) %>% mutate(draw = b)
}))
# 08_irf.R:121-122
summarise(lower = quantile(value, 0.025), upper = quantile(value, 0.975),
          cumulative_lower = quantile(cumulative, 0.025), cumulative_upper = quantile(cumulative, 0.975))
```

### 3.6 Jackknife IRF (dashed line in fig12)

Same as 3.2–3.4 with $A_k$ built from the jackknife coefficients $\tilde\theta$ (section 1.5); $\hat\Sigma$ still
from the full-sample OLS residuals; point estimate only.

```r
# 08_irf.R:60-62
if (jackknife) {
  coef_violence <- coef(half_panel_jackknife(data, violence, sanction, N_LAGS, controls))
  coef_sender   <- coef(half_panel_jackknife(data, sanction, violence, N_LAGS, controls))
}
# 08_irf.R:105   jackknife <- var_responses(estimation_sample, sanction, violence, controls, jackknife = TRUE)
```

---

## 4. Logit and PPML versions of the reaction functions (script 09, part 1; R3)

Common to all models in this section (`09_robustness.R:89–116`, `fit_nonlinear`):

- Same regressors as section 1.1 (2 own lags, 2 lags of the other variable, the controls if used), state and year
  dummies; estimated by maximum likelihood / pseudo-ML with `glm()`.
- **Dropped states:** logit — states whose outcome never changes in the sample; PPML — states whose outcome is always
  0. Their state dummy would go to $-\infty$; they carry no information (`09_robustness.R:91–96`).
- SE: `sandwich::vcovCL(model, cluster = gwcode, type = "HC0")` — the clustered sandwich built from the score
  contributions, without small-sample factor $(n-1)/(n-K)$ (`09_robustness.R:101`).
- Granger test: as in 1.4 with this covariance (`09_robustness.R:103–106`).
- Sample: the Table 1 estimation sample of the matching specification (`09_robustness.R:150–152`, rows with the nonlinear outcome observed), minus the
  dropped states.

```r
# 09_robustness.R:98-101
regressors <- c(lag_names(own, N_LAGS), lag_names(other, N_LAGS), controls, "factor(gwcode)", "factor(yr)")
model <- suppressWarnings(glm(reformulate(regressors, response = outcome), family = family, data = used,
                              control = glm.control(maxit = 100)))
covariance <- sandwich::vcovCL(model, cluster = used$gwcode, type = "HC0")
```

### 4.1 Logit (incidence sample)

Violence equation (`09_robustness.R:125–126`: outcome `viol_inc`, own `viol_inc`, other `new_sanction`):

$$ \Pr\big(V^{inc}_{it} = 1 \mid \cdot\big) = \Lambda(x_{it}),\qquad \Lambda(x) = \frac{1}{1+e^{-x}}, $$
$$ x_{it} = a_1 V^{inc}_{i,t-1} + a_2 V^{inc}_{i,t-2} + b_1 S^{inc}_{i,t-1} + b_2 S^{inc}_{i,t-2} + \gamma'X_{i,t-1} + \alpha_i + \tau_t $$

Sender equation (`09_robustness.R:127–128`): $\Pr(S^{inc}_{it}=1) = \Lambda(d_1 S^{inc}_{i,t-1} + d_2 S^{inc}_{i,t-2} + c_1 V^{inc}_{i,t-1} + c_2 V^{inc}_{i,t-2} + \eta'X_{i,t-1} + \mu_i + \delta_t)$.

Comparable scale (approximate average partial effect of the sum), with $\hat p_{it}$ the fitted probabilities in the
used sample of $N$ rows:

$$ \text{APE}_{sum} = (\hat b_1 + \hat b_2)\cdot \frac1N\sum_{i,t}\hat p_{it}(1-\hat p_{it}) $$

```r
# 09_robustness.R:107-108   fitted_values <- fitted(model)
#                          scale <- if (family$family == "binomial") mean(fitted_values * (1 - fitted_values)) else NA
# 09_robustness.R:113      average_partial_effect_sum = sum(b) * scale,
```

### 4.2 PPML (levels sample, `family = quasipoisson()`)

Violence equation, outcome **untransformed** deaths per 100,000 (`09_robustness.R:129–132`):

$$ E\big[y_{it} \mid \cdot\big] = \exp\Big(a_1 V^{lev}_{i,t-1} + a_2 V^{lev}_{i,t-2} + b_1 S^{lev}_{i,t-1} + b_2 S^{lev}_{i,t-2} + \gamma'X_{i,t-1} + \alpha_i + \tau_t\Big) $$

with $y$ = `deaths_pc` (raw deaths per 100,000) or `deaths_pc_winsorised`.

Note: the outcome is in raw deaths, the lagged violence regressors are still $V^{lev} = \ln(1+d^{pc})$ (`own = "viol_lev"`).

Winsorised outcome: $\min(d^{pc}_{it}, q_{0.99})$ with $q_{0.99}$ = 99th percentile of $d^{pc}$ over all window
state-years of the analysis panel (= 45.6):

```r
# 09_robustness.R:140-141
cap <- quantile(analysis$deaths_pc[analysis$in_window], WINSOR_QUANTILE, na.rm = TRUE)
analysis$deaths_pc_winsorised <- pmin(analysis$deaths_pc, cap)
```

Sender equation (`09_robustness.R:133–134`):
$E[S^{lev}_{it}] = \exp(d_1 S^{lev}_{i,t-1} + d_2 S^{lev}_{i,t-2} + c_1 V^{lev}_{i,t-1} + c_2 V^{lev}_{i,t-2} + \eta'X_{i,t-1} + \mu_i + \delta_t)$.

Estimating equations solved by `glm` (Poisson pseudo-ML): $\sum_{i,t}\big(y_{it} - \exp(W_{it}'\beta)\big)W_{it} = 0$.
Reported effect of the two cross-lags together: $\exp(\hat b_1 + \hat b_2) - 1$ = proportional change of $E[y]$
(`09_robustness.R:178`).

---

## 5. Script 09, parts 2–5: raw and capped deaths (R10), control check (D8), Yugoslavia (R9)

### 5.1 Part 2: Granger tests (`09_robustness.R:216–278`)

Define, for a cap $c$,

$$ D^{(c)}_{it} = \min\big(d^{pc}_{it},\ c\big),\qquad c \in \{\infty \text{ (raw)},\ q_{0.99} = 45.6,\ q_{0.95} = 6.2\} $$

($D^{(c)}$ is the column `deaths_level`.)

($q$ over all window state-years; cap applied to every year, including the years used as lags). Then section 1.1
with $V = D^{(c)}$ (outcome **and** lags) and $S = S^{lev}$:

$$ D^{(c)}_{it} = a_1 D^{(c)}_{i,t-1} + a_2 D^{(c)}_{i,t-2} + b_1 S^{lev}_{i,t-1} + b_2 S^{lev}_{i,t-2} + \gamma'X_{i,t-1} + \alpha_i + \tau_t + \varepsilon_{it} $$
$$ S^{lev}_{it} = d_1 S^{lev}_{i,t-1} + d_2 S^{lev}_{i,t-2} + c_1 D^{(c)}_{i,t-1} + c_2 D^{(c)}_{i,t-2} + \eta'X_{i,t-1} + \mu_i + \delta_t + u_{it} $$

OLS and jackknife, Granger tests, largest root exactly as in 1.2–1.6. Sample: the Table 1 **levels** sample (rows
required to have `viol_lev` and its lags), with $D^{(c)}$ and its lags merged in.

```r
# 09_robustness.R:230-231
cap <- quantile(data$deaths_pc[data$in_window], cap_quantile, na.rm = TRUE)
data$deaths_level <- pmin(data$deaths_pc, cap)        # cap applied to all years, also those used as lags
# 09_robustness.R:238-241  Table 1 levels sample, then lags of deaths_level joined in
estimation_sample <- build_estimation_sample(data, "n_new_cases", "viol_lev", N_LAGS, controls) %>%
  select(-starts_with("deaths_level")) %>%
  left_join(add_lags(data, "deaths_level", N_LAGS) %>% select(gwcode, yr, starts_with("deaths_level")), by = c("gwcode", "yr"))
# 09_robustness.R:243-247
equations <- list(violence = list(outcome = "deaths_level", other = "n_new_cases"),
                  sender   = list(outcome = "n_new_cases",  other = "deaths_level"))
  OLS       = fit_reaction_function(estimation_sample, eq$outcome, eq$other, N_LAGS, controls),
  jackknife = half_panel_jackknife(estimation_sample, eq$outcome, eq$other, N_LAGS, controls)
# 09_robustness.R:255   test <- wald_test(model, lag_names(other, N_LAGS))
```

### 5.2 Part 3: dynamics with $c = q_{0.99}$ (`09_robustness.R:313–428`)

- IRFs: section 3.1–3.5 with $V = D^{(q_{0.99})}$ = `deaths_capped`, $S$ = `n_new_cases`; three identifications;
  bootstrap with `set.seed(20261022)`, `IRF_BOOT_DRAWS` draws; **no jackknife IRF**. Shocks: one new case /
  +1 death per 100,000.
- Response function: section 2 with $E$ = `new_sanction`, $y$ = `deaths_capped` (raw and two-way FE).

```r
# 09_robustness.R:320-321  cap_p99 <- quantile(...deaths_pc[in_window], 0.99); deaths_capped <- pmin(deaths_pc, cap_p99)
# 09_robustness.R:324-332  var_responses(): same steps as 08_irf.R:64-77 (OLS only)
# 09_robustness.R:334-337  resample_states(): as 08_irf.R:81-86 (without original_gwcode)
# 09_robustness.R:350-355  set.seed(20261022); point estimate (draw 0) + N_BOOT bootstrap draws
# 09_robustness.R:378      deaths_capped_fe <- two_way_demean(response_data, "deaths_capped")
# 09_robustness.R:383-386  outcome_k <- lag_by_year(response_data, variable, -k)
#                          fit <- lm(outcome_k ~ new_sanction, data = sample_k); vcovCL(..., type = "HC1")
```

### 5.3 Part 4 (decision D8): same-sample control check (`09_robustness.R:462–555`)

Section 1.1 (both equations, FE-OLS, clustered by state) estimated with seven control sets $C$, all on **one common
sample**: the state-years where every control below is available (4,888 obs., 174 states):

$$ V_{it} = a_1 V_{i,t-1} + a_2 V_{i,t-2} + b_1 S_{i,t-1} + b_2 S_{i,t-2} + \gamma_C' X^{C}_{it} + \alpha_i + \tau_t + \varepsilon_{it} $$

(and the sender equation likewise), with $X^{C}_{it}$ one of

| Version | $X^{C}_{it}$ | Code (`CONTROL_VERSIONS`, `09_robustness.R:483–491`) |
|---|---|---|
| FE only | none | `character(0)` |
| stock t−1 | $K_{i,t-1}$ | `ctrl_stock` |
| stock t−3 | $K_{i,t-3}$ | `ctrl_stock_t3` |
| GDP growth | $g_{i,t-1}$ | `ctrl_gdp_growth` |
| democracy | $D_{i,t-1}$ | `ctrl_democracy` |
| all controls | $(K_{i,t-1}, g_{i,t-1}, D_{i,t-1})$ | `CONTROLS` |
| all, stock t−3 | $(K_{i,t-3}, g_{i,t-1}, D_{i,t-1})$ | `c(setdiff(CONTROLS, "ctrl_stock"), "ctrl_stock_t3")` |

plus FE only on the full no-controls sample (197 states) as reference. Why $K_{i,t-3}$: by the stock identity
(section 0.3), $K_{i,t-1} = K_{i,t-3} + S^{lev}_{i,t-1} + S^{lev}_{i,t-2} + \ldots$, so the stock in $t-1$ contains the
tested lags; the stock in $t-3$ is dated before both.

```r
# 09_robustness.R:481   analysis$ctrl_stock_t3 <- lag_by_year(analysis, "n_cases_received", 3)
# 09_robustness.R:497-510  granger_both_equations(): fit_reaction_function(..., cluster_se = FALSE), then
#                          model$vcov_clustered <- sandwich::vcovCL(model, cluster = cluster, type = "HC1"); wald_test()
# 09_robustness.R:518   common_sample <- build_estimation_sample(analysis, sanction, violence, N_LAGS, ALL_CONTROL_COLUMNS)
# 09_robustness.R:525   full_sample   <- build_estimation_sample(analysis, sanction, violence, N_LAGS)
```

### 5.4 Part 5 (R9): Yugoslavia attribution (`09_robustness.R:559–620`)

Section 1.1 (with and without `CONTROLS`), three versions:

- **main:** Table 1 as is.
- **without ex-Yugoslavia:** the estimation sample minus the 8 states $\mathcal Y$ with `ex_yugo_1991_2016 = 1` in any
  year (Yugoslavia/FRY, Serbia, Montenegro, Macedonia, Croatia, Bosnia-Herzegovina, Kosovo, Slovenia).
- **ex-Yugoslavia one cluster:** same estimates as main; in the clustered covariance of section 1.3 the cluster index
  is $g(i) = i$ for $i \notin \mathcal Y$ and $g(i) = \mathcal Y$ (one cluster) for $i \in \mathcal Y$.

```r
# 09_robustness.R:573   ex_yugoslav_states <- analysis %>% filter(ex_yugo_1991_2016 == 1) %>% distinct(gwcode, gw_name)
# 09_robustness.R:583-585
one_yugoslav_cluster <- ifelse(estimation_sample$gwcode %in% ex_yugoslav_states$gwcode, -1L, estimation_sample$gwcode)
without_yugoslavia   <- estimation_sample %>% filter(!gwcode %in% ex_yugoslav_states$gwcode)
# 09_robustness.R:586-591  granger_both_equations(...) for the three versions (cluster = one_yugoslav_cluster in the third)
```

---

## 6. GMM panel VAR (script 10; R8)

Same model as section 1.0. GMM removes the state effects by a transformation that keeps lagged levels valid as
instruments, then estimates $A_1, A_2, \Gamma$ from moment conditions. Implementation: `panelvar::pvargmm`; the
estimator is the one of Abrigo & Love (2016, eq. 2), `papers/abrigo-love-2016-…pdf`, sections 2–2.1.

### 6.1 Step 1: remove the year effects (`10_pvar_gmm.R:74–79`, `157–159`)

`pvargmm` has no year dummies, so every variable $x \in \{V, S, K, g, D, Y\}$ is demeaned by year first:

$$ \ddot x_{it} = x_{it} - \frac{1}{N_t} \sum_{j \,:\, x_{jt} \text{ observed}} x_{jt} $$

$N_t$ = number of states with $x$ observed in year $t$. Computed on the **whole analysis panel** (197 states, 1986–2019),
not on the Table 1 estimation sample. Under A1–A3 this is equivalent to year dummies up to an $O(1/N)$ term.

### 6.2 Step 2: forward orthogonal deviations (inside `pvargmm`, `transformation = "fod"`)

For every variable (dependent variables, their lags, controls), with $T_{it}$ = number of years of state $i$ after $t$
in which the variable is observed:

$$ x^{\ast}_{it} = \sqrt{\frac{T_{it}}{T_{it}+1}}\;\Big(\ddot x_{it} - \frac{1}{T_{it}} \sum_{s > t} \ddot x_{is}\Big) $$

Properties used:

- A state constant is removed: if $x_{it} = \lambda_i$ for all $t$, then $x^{\ast}_{it} = 0$.
- The last year of each state has no future values and is lost.
- If the $e_{it}$ are serially uncorrelated with constant variance (A3), the transformed errors $e^{\ast}_{it}$ are
  still serially uncorrelated (the scaling factor ensures this).
- $e^{\ast}_{it}$ depends only on $e_{it}, e_{i,t+1}, \ldots, e_{iT}$ — **not on the past**. So any variable dated
  $t-1$ or earlier is uncorrelated with $e^{\ast}_{it}$ under A2.

### 6.3 Step 3: the transformed equations

Applying FOD to the model of section 1.0 removes $\lambda_i$ (and $\phi_t$ was removed in step 1):

$$ z^{\ast}_{it} = A_1\, z^{\ast}_{i,t-1} + A_2\, z^{\ast}_{i,t-2} + \Gamma\, X^{\ast}_{i,t-1} + e^{\ast}_{it} $$

Written out, violence equation and sender equation:

$$ V^{\ast}_{it} = a_1 V^{\ast}_{i,t-1} + a_2 V^{\ast}_{i,t-2} + b_1 S^{\ast}_{i,t-1} + b_2 S^{\ast}_{i,t-2} + \gamma' X^{\ast}_{i,t-1} + \varepsilon^{\ast}_{it} $$

$$ S^{\ast}_{it} = c_1 V^{\ast}_{i,t-1} + c_2 V^{\ast}_{i,t-2} + d_1 S^{\ast}_{i,t-1} + d_2 S^{\ast}_{i,t-2} + \eta' X^{\ast}_{i,t-1} + u^{\ast}_{it} $$

Here $V^{\ast}_{i,t-1}$ is the FOD of $V$ in year $t-1$; it contains $V_{it}, V_{i,t+1}, \ldots$ and hence $e_{it}$, so
OLS on these equations would be inconsistent. The controls enter as `exog_vars` (treated as exogenous: they instrument
themselves). "No controls" version: drop the $\gamma, \eta$ terms.

### 6.4 Step 4: instruments and moment conditions

Instrument vector for the equation in year $t$ (one row per state-year; **collapsed**, `collapse = TRUE`: one column
per variable and lag, not one per variable, lag and year; missing values set to 0 as in Holtz-Eakin, Newey & Rosen):

$$ Z_{it} = \big(\ddot V_{i,t-2},\ \ddot V_{i,t-3},\ \ddot V_{i,t-4},\ \ddot V_{i,t-5},\ \ddot S_{i,t-2},\ \ddot S_{i,t-3},\ \ddot S_{i,t-4},\ \ddot S_{i,t-5},\ X^{\ast\prime}_{i,t-1}\big) $$

- Lags 2–5 of the year-demeaned **levels** (`min_instr_dependent_vars = 2L`, `max_instr_dependent_vars = 5L`).
  Lag 1 would also be valid under A2–A3 (see 6.2); starting at lag 2 keeps the instruments valid if the errors
  have first-order serial correlation, at some cost in instrument strength.
- Number of instruments per equation: $L = 2 \times 4 = 8$ without controls, $L = 8 + 3 = 11$ with controls.
- Difference-type GMM only (`system_instruments = FALSE`): no extra level equation with differenced instruments.

Moment conditions, one block per equation (same instruments in both):

$$ E\big[Z_{it}'\, \varepsilon^{\ast}_{it}\big] = 0, \qquad E\big[Z_{it}'\, u^{\ast}_{it}\big] = 0 $$

| | no controls | with controls |
|---|---|---|
| moment conditions ($2L$) | 16 | 22 |
| parameters (2 equations × (4 lags + controls)) | 8 | 14 |
| overidentifying restrictions = Hansen df | 8 | 8 |

(16 / 22 = `n_moment_conditions` (confirmed by the run of 2026-10-23; 24 before, with 4 controls); in `gmm_granger.csv`, `10_pvar_gmm.R:176`.)

**Instrument relevance** requires that $\ddot z_{i,t-2}, \ldots, \ddot z_{i,t-5}$ predict $z^{\ast}_{i,t-1}, z^{\ast}_{i,t-2}$.
For a persistent 0/1 series that rarely switches (conflict incidence), deep lags predict the forward deviation
poorly → weak instruments; this is the explanation given in `10_pvar_gmm.md` for the V → S incidence result.

### 6.5 Step 5: the GMM estimator

Stack all usable state-years ($n$ rows): $Y^{\ast}$ ($n \times 2$, columns $V^{\ast}, S^{\ast}$), $R^{\ast}$
($n \times m$, the regressors $V^{\ast}_{t-1}, V^{\ast}_{t-2}, S^{\ast}_{t-1}, S^{\ast}_{t-2}, X^{\ast}_{t-1}$;
$m = 4$ or $8$), $Z$ ($n \times L$), and $\mathbf A = (A_1, A_2, \Gamma)'$ ($m \times 2$, one column per equation).
Abrigo & Love (2016, eq. 2):

$$ \hat{\mathbf A} = \big(R^{\ast\prime} Z\, \hat W\, Z' R^{\ast}\big)^{-1}\, R^{\ast\prime} Z\, \hat W\, Z' Y^{\ast} $$

with one $L \times L$ weighting matrix $\hat W$ shared by both equations, so each column of $\hat{\mathbf A}$ is the
GMM estimate of one equation with the common instruments. Two steps (`steps = "twostep"`): step 1 with a fixed
$\hat W$ (no residuals needed), step 2 with $\hat W$ re-estimated from the step-1 residuals (efficient GMM);
for one equation with residuals $\hat e^{\ast}_i$ of state $i$ this is $\hat W_2 = \big(\sum_i Z_i'\hat e^{\ast}_i \hat e^{\ast\prime}_i Z_i\big)^{-1}$.
**Not verified from the package source** (not accessible from this session): the exact step-1 matrix, how the two
equations' residuals are combined in $\hat W_2$, and whether the two-step SEs are Windmeijer-corrected. Check with
`?pvargmm` or the panelvar paper (Sigmund & Ferstl 2021) on the Mac.

### 6.6 Tests

**Hansen J** (`hansen_j_test`, `10_pvar_gmm.R:132–138`): with $\bar g = \sum_i Z_i' \hat e^{\ast}_i$ evaluated at
the two-step estimate,

$$ J = \bar g'\, \hat W_2\, \bar g \;\sim\; \chi^2(\#\text{moments} - \#\text{parameters}) = \chi^2(8) $$

$H_0$: all moment conditions hold. Rejection → some instruments are invalid (or the model is misspecified, e.g.
serial correlation violating A3). A p-value close to 1 is a sign of too many instruments.

**Granger test.** The full GMM covariance from panelvar fails the consistency check in `10_pvar_gmm.R:115–130`
(`wald_uses_full_covariance = FALSE` in every row of `gmm_granger.csv`), so only the diagonal is used:

$$ W_{GMM} = \frac{\hat b_1^2}{se(\hat b_1)^2} + \frac{\hat b_2^2}{se(\hat b_2)^2} \;\approx\; \chi^2(2), \qquad se(\hat b_1 + \hat b_2) = \sqrt{se(\hat b_1)^2 + se(\hat b_2)^2} $$

(the covariance between the two lag coefficients is ignored; the test is approximate).

**Stability:** largest root of the companion matrix of section 1.6 with the GMM $A_1, A_2$ (`10_pvar_gmm.R:177`).
No IRFs are computed from GMM.

**Lag length** (Andrews & Lu 2001, `Andrews_Lu_MMSC`, `10_pvar_gmm.R:219–231`), for $p = 1, 2, 3$ without controls,
$k = 2$ variables, $q$ = number of instrument lags (here 4), $n$ = observations:

$$ \text{MMSC-BIC} = J - (q - p)\,k^2 \ln n, \qquad \text{MMSC-AIC} = J - 2\,(q - p)\,k^2, \qquad \text{MMSC-HQIC} = J - R\,(q - p)\,k^2 \ln\ln n,\ R > 2 $$

(Abrigo & Love 2016, section 2.2; lowest value preferred).

### 6.7 Sample

Whatever `pvargmm` can use from the year-demeaned analysis panel: the last year of every state is lost to FOD, and
the first two years of each state lack lags. E.g. incidence, no controls: 5,341 obs. / 197 states
(`gmm_granger.csv`) vs 5,538 in Table 1. The OLS / jackknife / GMM comparison is therefore on slightly different
samples.

### 6.8 Code

```r
# 10_pvar_gmm.R:58-65
GMM_SETTINGS <- list(
  transformation           = "fod",       # forward orthogonal deviations
  steps                    = "twostep",   # efficient two-step GMM
  system_instruments       = FALSE,       # difference GMM only (no level equation)
  collapse                 = TRUE,        # one instrument per lag, not one per lag and year
  min_instr_dependent_vars = 2L,          # instruments start at lag 2 ...
  max_instr_dependent_vars = 5L           # ... and stop at lag 5
)
# 10_pvar_gmm.R:74-79   step 1
demean_by_year <- function(data, variables) {
  data %>% group_by(yr) %>% mutate(across(all_of(variables), ~ .x - mean(.x, na.rm = TRUE))) %>% ungroup()
}
# 10_pvar_gmm.R:157-159
gmm_data <- analysis %>%
  select(gwcode, yr, all_of(c(violence, sanction, controls))) %>%
  demean_by_year(c(violence, sanction, controls))
# 10_pvar_gmm.R:163   steps 2-5 inside panelvar
model <- fit_gmm(gmm_data, c(violence, sanction), N_LAGS, controls)
# 10_pvar_gmm.R:82-92   fit_gmm(): do.call(pvargmm, c(list(dependent_vars = c(violence, sanction), lags = 2,
#                       data = gmm_data, panel_identifier = c("gwcode", "yr")), GMM_SETTINGS, exog_vars = controls))
# 10_pvar_gmm.R:176     n_moment_conditions <- nrow(model$weighting_matrix_second_step)
# 10_pvar_gmm.R:126     covariance <- if (usable) full_covariance[positions, positions] else diag(estimates$std_errors[equation, ]^2)
# 10_pvar_gmm.R:196-201 granger <- wald_test(granger_input, cross_terms)
# 10_pvar_gmm.R:177     var_root <- largest_var_root(estimates$coefficients[violence, ], estimates$coefficients[sanction, ], ...)
# 10_pvar_gmm.R:223-225 selection_model <- fit_gmm(selection_data, c(violence, sanction), n_lags); Andrews_Lu_MMSC(selection_model)
```

---

## 7. GDELT instead of UCDP violence (script 11; R12)

### 7.1 Variables (`11_gdelt.R:95–122`)

For state $i$, year $t$ (panel years 1976–2021; GDELT itself 1979–2021):

$$ G_{it} = \text{assault}_{it} + \text{fight}_{it} + \text{massviol}_{it} $$

Columns: $G$ = `gdelt_viol`; the three terms are `assault_norm1000`, `fight_norm1000`, `mass_violence_norm1000`.

(each term = reported events of that CAMEO type per 1,000 GDELT events of all types in $i,t$).

$$ V^{G,lev}_{it} = G_{it}/10 \quad(\%\text{ of all events}),\qquad m_i = \operatorname{median}_{t \in 1979\ldots2021} G_{it},\qquad V^{G,inc}_{it} = \mathbf 1\big[G_{it} > m_i\big] $$

Columns: $V^{G,lev}$ = `gdelt_lev`, $m_i$ = `gdelt_state_median`, $V^{G,inc}$ = `gdelt_inc`.

$m_i$ uses all of the state's GDELT years, including years after $t$. Controls are built exactly as in 0.3
(`11_gdelt.R:118–121`).

```r
# 11_gdelt.R:102   gdelt_viol = assault_norm1000 + fight_norm1000 + mass_violence_norm1000,
# 11_gdelt.R:112   mutate(gdelt_state_median = median(gdelt_viol[yr %in% GDELT_YEARS], na.rm = TRUE))
# 11_gdelt.R:114-115
mutate(gdelt_lev = gdelt_viol / 10,
       gdelt_inc = as.integer(gdelt_viol > gdelt_state_median))
```

### 7.2 Samples (`11_gdelt.R:64–69`, `128–140`)

| Window (`WINDOWS`) | `in_window` years |
|---|---|
| `ucdp_years` | 1991–2019 |
| `full_gdelt` | 1981–2021 |

States: ≥ 10 years in the window with all of `new_sanction`, `n_new_cases`, `gdelt_inc`, `gdelt_lev`
(`11_gdelt.R:135–139`). Thin-coverage version: `gdelt_lev`, `gdelt_inc` set to NA where
`gdelt_total_events` < 100 (`11_gdelt.R:130–133`). Estimation sample: `build_estimation_sample` as in 0.5.

### 7.3 Equations

Everything of sections 1 (Table 1, OLS + jackknife), 1.7 (lag grid), 2 (response functions) and 3 (IRFs, OLS,
bootstrap) with the violence variable replaced:

| Specification | $S$ | $V$ |
|---|---|---|
| incidence | `new_sanction` | `gdelt_inc` |
| levels | `n_new_cases` | `gdelt_lev` |

e.g. violence equation, incidence:

$$ V^{G,inc}_{it} = a_1 V^{G,inc}_{i,t-1} + a_2 V^{G,inc}_{i,t-2} + b_1 S^{inc}_{i,t-1} + b_2 S^{inc}_{i,t-2} + \gamma'X_{i,t-1} + \alpha_i + \tau_t + \varepsilon_{it} $$

**IRF shock size, levels:** the violence shock is one within-state standard deviation of `gdelt_lev` in the
estimation sample,

$$ \sigma_w = \operatorname{sd}\big(V^{G,lev}_{it} - \bar V^{G,lev}_{i}\big), \qquad \text{responses to the violence shock} = \sigma_w \cdot \Theta_h[\cdot, 1] $$

(incidence: $\sigma_w = 1$). The same $\sigma_w$ (from the original sample) scales every bootstrap draw. Draws:
`GDELT_BOOT_DRAWS`, default 99 (`11_gdelt.R:61`); seed 20261022.

```r
# 11_gdelt.R:270-297   estimate_var(): fit_reaction_function / half_panel_jackknife / wald_test / largest_var_root
# 11_gdelt.R:300-305   three samples: ucdp_years, full_gdelt, ucdp_years_thick (thin coverage removed)
# 11_gdelt.R:315       estimation_sample <- build_estimation_sample(data, sanction, violence, N_LAGS, controls)
# 11_gdelt.R:335-359   lag grid, as 04_reaction_functions.R:259-298
# 11_gdelt.R:378-425   response functions, as 07_empirical_response.R:57-93 (pairs: 11_gdelt.R:378-387)
# 11_gdelt.R:461-474   var_responses(), resample_states(), as in 08
# 11_gdelt.R:485-487   violence_shock <- if (levels) sd(x - ave(x, gwcode)) else 1
# 11_gdelt.R:496       mutate(value = ifelse(shock == "violence", value * violence_shock, value))
```

### 7.4 Validation against UCDP (`11_gdelt.R:157–180`)

On 1989–2019 state-years with both measures: pooled correlation $\operatorname{corr}(V^{G,lev}, V^{lev})$;
within-state correlation of the state-demeaned series; $\Pr(V^{G,inc}=1 \mid V^{inc}=1)$,
$\Pr(V^{G,inc}=1 \mid V^{inc}=0)$, $\Pr(V^{inc}=1 \mid V^{G,inc}=1)$,
with `ucdp_inc` = `viol_inc` and `ucdp_lev` = `viol_lev` rebuilt in `11_gdelt.R:105–106`.

---

## 8. LP-DiD event study (script 12; extension)

### 8.1 Definitions (`12_lpdid.R:86–94`)

Event $E_{it} \in \{0,1\}$; number of events in the 3 previous years (`CLEAN_WINDOW <- 3`, `12_lpdid.R:40`):

$$ P_{it} = E_{i,t-1} + E_{i,t-2} + E_{i,t-3} $$

$$ \text{treated: } D_{it} = \mathbf 1\big[E_{it} = 1 \text{ and } P_{it} = 0\big], \qquad \text{clean control: } E_{it} = 0 \text{ and } P_{it} = 0 $$

For $E$ = `viol_inc`, a treated year is a **conflict onset** after three conflict-free years. Rows with
$E_{it} = 1, P_{it} > 0$ (continuing events) and rows with $E_{it} = 0, P_{it} > 0$ (recently treated) are not used.

### 8.2 Equations, one regression per horizon $h = -3, \dots, 8$ (`12_lpdid.R:96–108`)

$$ h \ge 0:\qquad y_{i,t+h} - y_{i,t-1} \;=\; \beta_h D_{it} \;+\; \gamma_{1h}\, y_{i,t-1} \;+\; \gamma_{2h}\, y_{i,t-2} \;+\; \tau_{ht} \;+\; e_{iht} $$

$$ h \in \{-3, -2\}:\qquad y_{i,t+h} - y_{i,t-1} \;=\; \beta_h D_{it} \;+\; \tau_{ht} \;+\; e_{iht} \qquad\text{(no lagged outcomes: at } h=-2 \text{ the left side would be } y_{i,t-2}-y_{i,t-1}\text{)} $$

$$ h = -1:\qquad \beta_{-1} \equiv 0 \ \text{(reference year, not estimated)} $$

- $\tau_{ht}$: year dummies; **no state dummies** (the long difference removes state levels) and **no controls**.
- Sample at each $h$: $t$ in the window, treated or clean control, and $y_{i,t+h}, y_{i,t-1}, y_{i,t-2}$ observed
  (the lag condition also applies to $h < 0$, so all horizons use comparable rows).
- SE clustered by state (HC1); band $\pm 1.96\,se$.
- Pairs: as in section 2 (UCDP, `analysis_panel.csv`, `12_lpdid.R:162–163`) and with `gdelt_inc` / `gdelt_lev`
  (GDELT panel from 11, both windows, `12_lpdid.R:186–197`).

```r
# 12_lpdid.R:88
past_events <- Reduce(`+`, lapply(seq_len(CLEAN_WINDOW), function(j) lag_by_year(data, spec$event, j)))
# 12_lpdid.R:91-94
treated       = as.integer(.data[[spec$event]] == 1 & past_events == 0),
clean_control = .data[[spec$event]] == 0 & past_events == 0,
outcome_lag1  = lag_by_year(data, spec$outcome, 1),
outcome_lag2  = lag_by_year(data, spec$outcome, 2)
# 12_lpdid.R:102-108
data$change_h <- value_at(data, spec$outcome, h) - data$outcome_lag1
sample_h <- data %>% filter(in_window, treated == 1 | clean_control,
                            !is.na(change_h), !is.na(outcome_lag1), !is.na(outcome_lag2))
regression <- if (h >= 0) change_h ~ treated + outcome_lag1 + outcome_lag2 + factor(yr)
              else        change_h ~ treated + factor(yr)
clustered_estimate(regression, sample_h, "treated")       # 12_lpdid.R:75-81: lm + vcovCL(HC1)
```

---

## 9. Data diagnostics (script 03)

### 9.1 Which series are tested (`03_data_diagnostics.R:62–68`)

Per state and series (1989–2019): "too short" (< 10 years), "gaps", "constant" (one value), "almost constant"
(fewer than 3 years differ from the state's median), otherwise "testable". Only testable series are tested; no
state leaves the VAR sample because of this.

### 9.2 Unit-level ADF (`03_data_diagnostics.R:74–92`)

$$ \Delta y_{it} = \kappa_i + \rho_i\, y_{i,t-1} + \sum_{j=1}^{q_i}\phi_{ij}\,\Delta y_{i,t-j} + e_{it}, \qquad q_i \in \{0,1,2\} \text{ chosen by AIC on a common sample}, \qquad H_0: \rho_i = 0 $$

Statistic $t(\hat\rho_i)$; p-value $p_i$ from the MacKinnon (1996) distribution, intercept case
(`urca::punitroot(t, N = Inf, trend = "c")`, `03_data_diagnostics.R:95–100`).

### 9.3 Panel combinations (`03_data_diagnostics.R:136–167`)

With $N$ tested states (p-values clamped to $[10^{-12}, 1-10^{-12}]$, line 137):

$$ \text{Maddala–Wu: } P = -2\sum_{i=1}^{N}\ln p_i \sim \chi^2(2N), \qquad \text{Choi: } Z = \frac{1}{\sqrt N}\sum_{i=1}^{N}\Phi^{-1}(p_i) \sim N(0,1)\ (\text{reject for very negative } Z) $$

```r
# 03_data_diagnostics.R:163-167
maddala_wu_chi2  = -2 * sum(log(p)),
maddala_wu_p     = pchisq(-2 * sum(log(p)), df = 2 * n_tested, lower.tail = FALSE),
choi_z           = sum(qnorm(p)) / sqrt(n_tested),
choi_p           = pnorm(sum(qnorm(p)) / sqrt(n_tested)),
```

### 9.4 CADF / CIPS (Pesaran 2007; `03_data_diagnostics.R:104–114`, `141–152`)

On the balanced sub-panel of testable states (all 31 years), with $\bar y_t$ = cross-state mean in year $t$:

$$ \Delta y_{it} = \kappa_i + \rho_i\, y_{i,t-1} + \delta_{0i}\,\bar y_{t-1} + \delta_{1i}\,\Delta\bar y_t + \phi_i\,\Delta y_{i,t-1} + \delta_{2i}\,\Delta\bar y_{t-1} + e_{it} $$

$$ \text{CIPS} = \frac1N\sum_i \min\big(\max(t_i, -6.19),\ 2.61\big),\qquad t_i = t(\hat\rho_i) $$

critical values / p-value from `plm:::critvals.cips(..., type = "drift", truncated = TRUE)`.

```r
# 03_data_diagnostics.R:110   fit <- lm(dy ~ y_lag + ybar_lag + dybar + dy_lag1 + dybar_lag1, data = design)
# 03_data_diagnostics.R:149   cips <- mean(pmin(pmax(cadf$t, CADF_TRUNCATION[1]), CADF_TRUNCATION[2]))
```

All of 9.2–9.4 are repeated on year-demeaned series $y_{it} - \bar y_t$ (`03_data_diagnostics.R:57`, 182–186),
testing the same states.

### 9.5 Persistence (`03_data_diagnostics.R:209–224`)

$$ y_{it} = \rho\, y_{i,t-1} + \alpha_i + \tau_t + e_{it}\ \ (\text{OLS}), \qquad \hat\rho^{corr} = \hat\rho + \frac{1+\hat\rho}{\bar T - 1},\quad \bar T = \frac{\#\text{obs}}{\#\text{states}} $$

For 0/1 series also $\Pr(y_{it} = 1 \mid y_{i,t-1} = 0)$ and $\Pr(y_{it} = 1 \mid y_{i,t-1} = 1)$ (sample shares).

### 9.6 VAR lag-length criteria (`03_data_diagnostics.R:254–267`)

Section 1.1 without controls, $p = 1, 2, 3$, all on the sample where 3 lags exist; with $\hat\Sigma_p$ the
$2\times2$ residual covariance (divided by $n$) and $m = 2\cdot2\cdot p$ lag coefficients:

$$ \text{AIC}(p) = \ln|\hat\Sigma_p| + \frac{2m}{n},\qquad \text{BIC}(p) = \ln|\hat\Sigma_p| + \frac{m\ln n}{n} $$

```r
# 03_data_diagnostics.R:260-267
residuals_matrix <- cbind(residuals(fit_reaction_function(sample_all_lags, violence, sanction, n_lags)),
                          residuals(fit_reaction_function(sample_all_lags, sanction, violence, n_lags)))
log_det <- log(det(crossprod(residuals_matrix) / n))
m <- 2 * 2 * n_lags
aic = log_det + 2 * m / n, bic = log_det + m * log(n) / n
```

---

## 10. Model diagnostics (script 06)

Uses the 8 OLS equations of Table 1 (`04_reaction_functions.R:93` saves them; `06_model_diagnostics.R:96–112`
loops over them).

### 10.1 Residual autocorrelation (`06_model_diagnostics.R:49–61`)

With $\hat e_{it}$ the FE-OLS residual of one equation, for $k = 1, 2$, pooled OLS:

$$ \hat e_{it} = \kappa + \rho_k\, \hat e_{i,t-k} + v_{it}, \qquad H_0: \rho_k = -\frac{1}{\bar T - 1}, \qquad z = \frac{\hat\rho_k + 1/(\bar T - 1)}{se(\hat\rho_k)},\ p = 2\Phi(-|z|) $$

$-1/(\bar T-1)$ is the correlation that within-demeaning creates when the true errors are serially uncorrelated;
$se$ clustered by state (HC1).

### 10.2 Pesaran CD (`06_model_diagnostics.R:69–89`)

Residuals arranged as a year × state matrix; states with ≥ 10 observed years and non-zero variance; for every pair
$i<j$ with $T_{ij} \ge 10$ common years, $\hat\rho_{ij}$ = correlation of their residuals over the common years:

$$ \text{CD} = \frac{1}{\sqrt{\#\text{pairs}}}\sum_{i<j}\sqrt{T_{ij}}\;\hat\rho_{ij} \;\sim\; N(0,1) $$

Computed for all states and for states whose outcome varies (`06_model_diagnostics.R:70–73`).

```r
# 06_model_diagnostics.R:81-85
overlap  <- crossprod(observed * 1)                               # T_ij
correlations <- suppressWarnings(cor(wide, use = "pairwise.complete.obs"))
use_pair <- upper.tri(overlap) & overlap >= MIN_OVERLAP & !is.na(correlations)
rho <- correlations[use_pair]
cd  <- sum(sqrt(overlap[use_pair]) * rho) / sqrt(sum(use_pair))
```

### 10.3 Stability

Collected from `table1_granger.csv` (OLS, jackknife; section 1.6) and `gmm_granger.csv` (section 6.2)
(`06_model_diagnostics.R:122–130`).

---

## 11. Which equation produces which result file

| Result | Section | Script | Output |
|---|---|---|---|
| Table 1 (Granger tests, coefficients) | 1.1–1.6 | 04 | `table1_reaction_functions.md`, `table1_coefficients.csv`, `table1_granger.csv` |
| Table 2 (lag grid) | 1.7 | 04 | `table2_lag_grid.md/.csv` |
| Response functions (fig10) | 2 | 07 | `empirical_response.md`, `response_functions.csv` |
| IRFs (fig12, fig13) | 3 | 08 | `irf_summary.md`, `irf_results.csv` |
| Logit / PPML | 4 | 09 part 1 | `robustness_nonlinear.md/.csv` |
| Raw / capped deaths | 5.1–5.2 | 09 parts 2–3 | `robustness_raw_deaths.md/.csv`, `robustness_capped_dynamics.md`, fig17 |
| Same-sample control check (D8) | 5.3 | 09 part 4 | `robustness_controls.md/.csv` |
| Yugoslavia (R9) | 5.4 | 09 part 5 | `robustness_yugoslavia.md/.csv` |
| GMM | 6 | 10 | `gmm_pvar.md`, `gmm_granger.csv`, `gmm_coefficients.csv`, `gmm_lag_selection.csv` |
| GDELT | 7 | 11 | `gdelt_results.md`, `gdelt_*.csv`, fig14, fig15 |
| LP-DiD | 8 | 12 | `lpdid.md`, `lpdid_event_study.csv`, fig11, fig16 |
| Data diagnostics | 9 | 03 | `data_diagnostics.md`, `diag_*.csv` |
| Model diagnostics | 10 | 06 | `model_diagnostics.md`, `diag_residual_autocorrelation.csv`, `diag_cross_section_dependence.csv`, `diag_stability.csv` |

---

## 12. Plan vs code: differences found while writing this file

1. ~~`ex_yugo_1991_2016` is not lagged~~ — resolved 2026-10-23: the dummy was removed from `CONTROLS`; the
   Yugoslavia attribution issue is handled in section 5.4 (R9).
2. **Response functions** (section 2): the plan (ANALYSIS_PLAN section 5) writes
   $[\bar V_{t+k} \mid S_t=1] - \bar V$ divided by the mean number of new cases in event years. The code compares
   with **non-event** years ($E_{it}=0$), not the overall mean, and does **not** divide by the event size. Either
   the plan text or the code should change.
3. **Two-way demeaning in 07** uses every panel year where the outcome exists (sanction outcomes: also 1986–88),
   while event years are 1989–2019.
4. **GMM sample** (section 6.3) is not the Table 1 sample: year means over the whole analysis panel, no common
   complete-case filter, FOD drops the last year of each state (5,341 vs 5,538 obs. without controls). The
   OLS / jackknife / GMM comparison in `gmm_pvar.md` is therefore on slightly different samples.
5. **GMM Wald test ignores the covariance of the two lags** (`wald_uses_full_covariance = FALSE` for all rows).
6. **Stock control** contains $S_{t-1}, S_{t-2}$ mechanically (section 0.3) — relevant for decision D8.
7. **GDELT incidence threshold** $m_i$ uses all years of the state, including future ones (not predetermined).
8. **Standard-error flavours:** OLS HC1 (with $K$ incl. all dummies), logit/PPML HC0; immaterial with ~170 clusters.
