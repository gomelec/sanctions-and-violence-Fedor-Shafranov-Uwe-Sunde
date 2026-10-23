# 03 — Data diagnostics: what they mean and what we found

Script: `empirics/scripts/03_data_diagnostics.R` · Output: `results/tables/data_diagnostics.md`, `diag_*.csv`
Run of 2026-10-21 19:35, window 1989–2019. Test mechanics: `tests_explained.md`, sections 2–4.

**Purpose.** These checks come *before* estimation. They ask whether the data allow a VAR in levels at all
(stationarity), how sticky each series is, whether the panel is balanced, and how many lags the VAR needs.
None of them is a result about sanctions and violence; they decide whether the later results can be trusted.

**Verdict in one line.** All four series are stationary, persistence is clearly below 1, and two lags are a
reasonable default (BIC chooses 2 for incidence, 3 for levels). Nothing here argues against the VAR(2) in levels.

---

## D1. Which state-series can be tested at all?

A unit-root test needs a series that moves. Many states never experience the event:

| Series | Testable | Almost constant (1–2 deviating years) | Constant |
|---|---|---|---|
| New sanction (0/1) and count | 102 | 64 | 31 |
| Conflict (0/1) | 63 | 34 | 100 |
| log(1 + deaths per 100k) | 97 | 22 | 78 |

**Meaning.**
- 100 of 197 states are *never* in conflict (≥ 25 deaths) in 1989–2019, and 31 never receive a new sanction.
  A constant series is trivially stationary. It has no unit root; it just cannot be put through an ADF test.
- "Almost constant" states (e.g. one sanction in 31 years) make the ADF regression degenerate, so they are
  also not tested.
- **These states stay in the estimation sample.** Dropping them would select on the outcome: we would keep
  only states that were violent or sanctioned, and the "effect" of sanctions would be estimated among states
  already in trouble. This was the concern you raised about "a lot of countries being excluded"; the answer is
  that the exclusion applies only to the *test*, not to the regressions.
- The deaths series is testable for more states than the conflict dummy (97 vs 63) because low-level deaths
  (below the 25-death threshold) still vary.

## D2. Unit-root tests

H0 in all tests: every state's series has a unit root. Rejection = stationary.

| Series | States tested | Share rejecting individually (5%) | Maddala–Wu | Choi | CIPS |
|---|---|---|---|---|---|
| New sanction (0/1) | 102 | 0.93 | p < 0.001 | p < 0.001 | −3.11, p < 0.01 |
| New sanction cases | 102 | 0.92 | p < 0.001 | p < 0.001 | −3.30, p < 0.01 |
| Conflict (0/1) | 62 | 0.53 | p < 0.001 | p < 0.001 | −2.68, p < 0.01 |
| log deaths per 100k | 97 | 0.61 | p < 0.001 | p < 0.001 | −3.02, p < 0.01 |

(Year-demeaned versions: same conclusion, all p < 0.01; individual rejection shares 0.87 / 0.87 / 0.52 / 0.42.)

**Meaning.**
- **New sanctions:** a flow, an event-type variable. About 93% of the testable states reject a unit root on
  their own, despite only ~30 years each. This is the expected outcome: a new sanction this year says little
  about next year.
- **Conflict and deaths:** about half of the states reject individually. That is not evidence of unit roots
  in the other half. With T ≈ 30 and a persistent series (conflict spells last years), a single-state ADF test
  has low power. The panel tests combine the information and reject strongly.
- **CIPS** removes common shocks (cross-section averages) and still rejects at 1% for every series.
  Stationarity is therefore not an artefact of cross-state correlation.
- **Year-demeaned version:** the model has year fixed effects, so what enters the VAR is the series net of
  year means. The conclusion is unchanged. The lower rejection share for deaths (0.42) reflects lower power
  after removing the common component, not a different conclusion.

**Consequence.** The VAR is estimated in levels (no differencing). Differencing a 0/1 event variable would
also make the coefficients hard to interpret.

## D3. Persistence

| Series | FE AR(1) | Nickell-corrected | Pooled, no FE | P(1 \| 0 last year) | P(1 \| 1 last year) |
|---|---|---|---|---|---|
| New sanction (0/1) | 0.14 | **0.18** | 0.21 | 0.086 | 0.295 |
| New sanction cases | 0.08 | **0.12** | 0.15 | | |
| Conflict (0/1) | 0.44 | **0.49** | 0.77 | 0.045 | 0.817 |
| log deaths per 100k | 0.64 | **0.70** | 0.81 | | |

**Meaning.**
- **Nickell correction:** with state fixed effects and T ≈ 30, the FE AR(1) is biased down by about
  (1 + ρ)/(T − 1) ≈ 0.04–0.06. That is small relative to the coefficient but large relative to its standard
  error, which is why Table 1 also reports the half-panel jackknife.
- **Pooled vs FE:** the pooled value (0.77 for conflict) mixes persistence *within* a state with permanent
  differences *between* states (some states are always at war). The FE value (0.49) is the within-state
  dynamics that the VAR estimates.
- **Switching probabilities:** a state at peace has a 4.5% chance of entering conflict next year; a state in
  conflict stays there with 82% probability. Conflict comes in spells. New sanctions are nearly events: 8.6% after
  a year without one, 29.5% after a year with one (senders often follow up).
- All values are well below 1, consistent with D2.

**Why it matters.** Violence is strongly persistent and sanctions are not. A sanction effect on violence must
therefore show up against a strong own-dynamics term, while the sender equation is driven mostly by shocks.

## D4. Panel balance

167 of 197 states have complete main variables in all 31 years. The unbalanced ones were created or dissolved
in the window (post-Soviet and post-Yugoslav states, Eritrea, Timor-Leste, …). The balanced sub-panel is used
by CIPS here and is the planned sample for the heterogeneous Granger test (script 05).

## D5. Lag length (system AIC/BIC, common sample 5,341 obs.)

| Specification | BIC chooses | AIC chooses |
|---|---|---|
| Incidence | 2 | 3 |
| Levels | 3 | 3 |

**Meaning.** The differences between 2 and 3 lags are small (BIC −5.5756 vs −5.5736 for incidence;
−2.9250 vs −2.9260 for levels). Two lags is the baseline, matching Jaeger & Paserman's choice for annual-type
dynamics. The lag grid in script 04 shows that Granger results do not depend on going to 3 lags. Lag 1 alone is
too few for the sanctions → violence direction, whose effect sits at t−2.

---

## What these diagnostics do not tell us

- They say nothing about the direction or size of the relationship; that is scripts 04, 07, 08 and 10.
- Stationarity of each series does not guarantee that the *residuals* of the VAR are well behaved. That is
  checked after estimation in script 06.
- A constant series is excluded only from testing. Its states still provide identifying variation for the
  other equation and for the year effects.
