# The tests used in this project, explained

What each test asks, how it is computed here, how to read it, and where it appears. Written 2026-10-21 for the
scripts in `empirics/scripts/`. For the results see the note of each script (index: `README.md` in this folder).

**General reading rule.** Every test has a null hypothesis H0. A small p-value (below 0.05) means the data are
unlikely under H0, so H0 is rejected. A large p-value does **not** prove H0; it only means the data cannot
reject it (possibly for lack of power). Whether rejecting is "good" depends on the test: for a Granger test a
rejection is a finding; for a Hansen test or a residual-autocorrelation test a rejection is a warning.

| Test | Question | H0 | Rejection means | Script |
|---|---|---|---|---|
| Granger (Wald χ²) | Does the past of X help predict Y? | all lags of X have zero coefficients | X Granger-causes Y (a finding) | 04, 10 |
| ADF, Maddala–Wu, Choi | Does the series have a unit root? | unit root in every state | series is stationary (good) | 03 |
| CIPS | Same, allowing for common shocks | unit root in every state | stationary (good) | 03 |
| Persistence / Nickell correction | How sticky is the series? | — (descriptive) | — | 03 |
| AIC / BIC lag criteria | How many lags fit best? | — (model selection) | — | 03, 04, 10 |
| Residual autocorrelation (Wooldridge) | Are the lags enough? | no serial correlation in the errors | VAR misses dynamics (warning) | 06 |
| Pesaran CD | Are residuals correlated across states? | no cross-state correlation | common shocks remain (warning) | 06 |
| VAR stability | Do shocks die out? | — (eigenvalue check) | root ≥ 1: unstable (warning) | 04, 06, 10 |
| Hansen J | Are the GMM instruments valid? | instruments valid | instruments invalid (warning) | 10 |
| Andrews–Lu MMSC | GMM lag length | — (model selection) | — | 10 |
| Half-panel jackknife | Bias correction, not a test | — | — | 04, 08 |
| Country-cluster bootstrap | Uncertainty of impulse responses | — | band excludes 0: significant | 08 |
| Event-study pre-trends (extension) | Did treated and controls differ before the event? | no difference before the event | selection / anticipation (warning) | 12 |

---

## 1. Granger causality (Wald χ² test)

**Question.** Does the past of one variable help predict another, beyond what the other variable's own past
already predicts? This is the central test of Jaeger & Paserman (2008) and of this project.

**How it is computed.** In the violence equation

    V_it = a1 V_i,t-1 + a2 V_i,t-2 + b1 S_i,t-1 + b2 S_i,t-2 + controls + state FE + year FE + e_it

the test is H0: b1 = b2 = 0 ("new sanctions do not Granger-cause violence"). The Wald statistic is
W = b' V⁻¹ b, where b are the estimated coefficients and V their covariance matrix (clustered by state). Under
H0, W follows a χ² distribution with as many degrees of freedom as restrictions (2 with two lags). The sender
equation is tested the same way (H0: lags of violence = 0).

**How to read it.** A large χ² (small p) means the other variable's past carries predictive information. The
**sign** comes from the coefficients (we also report their sum): negative b's = violence lower after
sanctions; positive = higher. The test is joint: single lags can be insignificant while the block is
significant, and vice versa.

**What it is not.** Granger causality is *predictive precedence*, not causation. It can arise from a third
factor that moves both variables with different delays, or from forward-looking behaviour (senders imposing
sanctions because they expect violence). With annual data, anything that happens within the same year is not
covered at all: the test only uses lags.

**Panel versions.** Ours is the *pooled* test (Holtz-Eakin, Newey & Rosen 1988): the lag coefficients are
assumed equal across states, and the test asks whether they are zero on average. Planned in script 05:
Juodis, Karavias & Sarafidis (2021), which lets each state have its own persistence and corrects the
Nickell bias; Dumitrescu & Hurlin (2012), which averages state-by-state tests.

---

## 2. Unit-root tests (stationarity)

**Why.** A VAR in levels assumes the series are stationary: shocks fade and the series returns to its mean. A
series with a unit root drifts permanently (like a random walk); regressions with such series can show
"spurious" relationships, and impulse responses do not die out.

### 2a. ADF test for one state

The augmented Dickey–Fuller regression for one state's series y:

    Δy_t = α + ρ y_t-1 + c1 Δy_t-1 + c2 Δy_t-2 + e_t

H0: ρ = 0 (unit root). The test statistic is the t-value of ρ; it does not follow the usual t-distribution, so
p-values come from MacKinnon's (1996) distribution (`urca::punitroot`). The number of lagged differences
(0–2) is chosen by AIC. With ~30 years per state, a single ADF test has **low power**: it often fails to
reject even for a stationary series. That is why panel versions combine many states.

### 2b. Maddala–Wu and Choi (panel versions)

Both combine the ADF p-values p_i of all testable states:

- **Maddala–Wu:** P = −2 Σ log(p_i), χ² with 2N degrees of freedom under H0.
- **Choi:** Z = Σ Φ⁻¹(p_i) / √N, standard normal under H0 (very negative = reject).

H0: every state has a unit root. **Rejection means: at least some states are stationary** — not necessarily all.
Hence we also report the *share of states rejecting individually*.

### 2c. CIPS (Pesaran 2007)

The tests above assume states are independent. Common shocks (a global wave of sanctions, the end of the Cold
War) make them correlated, which can make the tests over-reject. CIPS adds the cross-state averages of the
series to each state's ADF regression ("cross-sectionally augmented" ADF, CADF) so that common shocks are
absorbed, and averages the state statistics. Individual statistics are truncated at [−6.19, 2.61] (Pesaran's
recommendation, which tames states with almost perfect fits). Critical values come from Pesaran's tables, so
the p-value is reported as a bound ("< 0.01"). Needs a balanced panel, so it uses the states present in all 31
years.

### 2d. Which states can be tested

A series that never changes (a state never in conflict: all zeros) has **no unit root** — a constant is
trivially stationary — but the ADF regression cannot be computed for it. We classify each state × series as
*constant*, *almost constant* (only 1–2 deviating years; the regression is degenerate), *too short / gaps*, or
*testable*, and test only the testable ones. **No state leaves the estimation sample because of this**
(plan 6a): dropping never-violent states would select on the outcome.

### 2e. Year-demeaned version

The model has year fixed effects, so the relevant series is the one net of year means. The tests are repeated
on year-demeaned series, for the *same* states as the raw version (demeaning an all-zero series creates
spurious variation; testing it would be meaningless).

---

## 3. Persistence (descriptive, script 03)

How strongly a series depends on its own past.

- **Fixed-effects AR(1):** coefficient of y_t-1 in a regression with state and year fixed effects. It is biased
  downward by about (1 + ρ)/(T − 1) (Nickell 1981); we report the corrected value.
- **Pooled AR(1) without fixed effects:** includes the persistent differences *between* states (some states
  are always at war), hence larger.
- **Switching probabilities for 0/1 series:** P(1 this year | 0 last year) = probability of a start;
  P(1 | 1) = probability that it continues.

Low persistence = event-like series (new sanctions); high persistence = spells (conflict). Values clearly
below 1 support stationarity.

---

## 4. Lag-length criteria (AIC, BIC, Andrews–Lu)

How many lags the VAR needs. Each criterion trades fit against the number of parameters:

    AIC = log|Σ| + 2m/n,   BIC = log|Σ| + m·log(n)/n

Σ = covariance of the residuals of the two equations, m = number of lag coefficients, n = observations.
Lower is better. BIC penalises extra lags more and tends to choose fewer. All lag lengths must be compared on
the **same sample** (we use the years where 3 lags are available).

For GMM, Andrews & Lu (2001) define analogous criteria from the Hansen J statistic (MMSC-BIC, -AIC, -HQIC).

**Caveat.** Criteria judge overall fit. An effect that appears only at a specific lag (here: violence two
years after a sanction) can be missed by a criterion that prefers fewer lags. The lag grid (Table 2) shows the
Granger tests for every lag combination instead.

---

## 5. Residual serial correlation (script 06)

**Question.** Are the lags enough? If the VAR misses dynamics, its residuals are still autocorrelated. Then
the Granger tests and impulse responses are distorted, and GMM instruments (older lags) become invalid.

**How.** Regress the fixed-effects residual on its own lag k (k = 1, 2), clustered by state. **The null value
is not 0**: fixed-effects residuals are demeaned within each state, and demeaning alone creates a correlation
of −1/(T − 1) between residuals of the same state (about −0.037 with T ≈ 28). So H0 is ρ = −1/(T − 1)
(Wooldridge 2010, section 10.5.4).

**How to read it.** p < 0.05 = remaining autocorrelation → add lags (to that equation). Look at the size too:
with ~5,000 observations, tiny deviations can be significant.

---

## 6. Cross-sectional dependence: Pesaran CD test (script 06)

**Question.** After the year effects, are the residuals of different states still correlated? That happens
when common shocks hit states with different strength (a global sanction wave matters more for some states).
Standard errors clustered by state assume independence across states and would then be too small.

**How.** For every pair of states i, j with at least 10 common years, compute the correlation ρ_ij of their
residuals over the common years T_ij. Then

    CD = Σ_pairs √T_ij ρ_ij / √(number of pairs)    ~ N(0, 1) under H0 (no cross-state correlation)

**Two versions, and why.** For a state whose outcome never changes (never in conflict), the residual is just
minus the fitted year effects — the *same* series for all such states. They are then mechanically correlated
with each other, which inflates CD without saying anything about common shocks. We therefore report CD for
all states and for states whose outcome varies. Read the second one.

**How to read it.** With thousands of pairs the test is very powerful; also look at the mean correlation. A
small but significant mean correlation (around 0.02) indicates weak common shocks → check robustness with
Driscoll–Kraay standard errors or the bootstrap; a large one would require a different model (e.g. common
factors, Nazlioglu & Karul 2024).

---

## 7. VAR stability (eigenvalue check)

Write the two equations as one system and stack the lags into the "companion matrix". If all its
eigenvalues have modulus below 1, every shock dies out over time: the system is stable, and impulse responses
are well defined. The largest modulus (the "largest root") is reported for every model. Values near 1 mean
very slow decay (close to a unit root); above 1, shocks explode.

---

## 8. Hansen J test (GMM, script 10)

GMM uses older lags as instruments and has more instruments (moment conditions) than coefficients. If all
instruments are valid, the extra moment conditions should hold approximately; the Hansen J statistic measures
how badly they fail and is χ² with (instruments − coefficients) degrees of freedom.

- **Rejection (p < 0.05):** some instruments are invalid (e.g. remaining serial correlation) → GMM estimates
  are not trustworthy.
- **p close to 1:** also a warning: with too many instruments the test loses power (Roodman 2009).
- **χ²(0):** exactly identified, nothing to test (our first GMM run; fixed by using lags 2–5 as instruments).

Rule of thumb: the number of instruments should stay well below the number of states.

---

## 9. Bias corrections and uncertainty (not tests, but used throughout)

**Nickell bias.** With state fixed effects and a lagged dependent variable, OLS is biased by roughly 1/T: own
persistence is understated, other coefficients can be distorted. With ~170 states and ~30 years, the bias is
large relative to the standard errors (Juodis et al. 2021; Mei, Sheng & Shi 2026).

**Half-panel jackknife** (Dhaene & Jochmans 2015): estimate on the full sample and on each half of the years;
b_jackknife = 2·b_full − (b_first + b_second)/2. Each half has twice the bias, so the combination removes the
first-order term. Reported next to OLS in Tables 1–2 and as a dashed line in the impulse-response figures.

**Clustered standard errors.** Allow arbitrary correlation of the errors within a state over time and
heteroskedasticity; assume independence across states (see the CD test).

**Country-cluster bootstrap** (script 08): draw states with replacement, re-estimate, recompute the impulse
responses; repeat (199 draws by default); the 2.5th and 97.5th percentiles form the 95% band. Resampling whole
states keeps each state's time pattern intact.

---

## 10. Event-study pre-trends (script 12, LP-DiD extension)

In the LP-DiD event study, the coefficients for years *before* the event (h = −3, −2) compare how treated
states and clean controls evolved before anything happened. Estimates near zero support the comparison
(similar trends before the event). Clear deviations indicate selection or anticipation: the event happened in
states that were already on a different path.
