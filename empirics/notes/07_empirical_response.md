# 07 — Empirical response functions (Jaeger & Paserman, Fig. 2)

Script: `empirics/scripts/07_empirical_response.R` · Output: `results/tables/empirical_response.md`,
`response_functions.csv`, `results/figures/fig10_response_functions.png`. Numbers from the run of 2026-10-21
(unchanged when the LP-DiD part was moved to script 12 on 2026-10-22).

**What it is.** The model-free counterpart of the VAR, as in Jaeger & Paserman's Figure 2: for each horizon k,
the difference between the mean outcome k years after an event year and the mean in all other years
(regression of y at t+k on the event dummy at t). No model of the two variables' joint dynamics. Events: a year
with a new sanction, or a conflict year.

Two versions:
- **raw** — plain means, as in JP. In a panel this mixes "after an event" with "in a country that often has
  events" (conflict-prone states are sanctioned more and are violent in every year).
- **two-way FE** — outcome net of state and year means first, so only deviations from the state's own normal
  level count. This is the version to read.

## Two-way FE version

| Outcome after event | h = −2 | h = −1 | h = 0 | h = 1 | h = 2 | h = 3 | h = 5 |
|---|---|---|---|---|---|---|---|
| Conflict after a new sanction | 0.037*** | 0.045*** | 0.073*** | 0.050*** | 0.020 | 0.019 | 0.015 |
| log deaths after a new sanction | 0.065* | 0.118*** | 0.224*** | 0.135*** | 0.033 | 0.023 | 0.026 |
| New sanction after a conflict year | 0.009 | 0.030*** | 0.049*** | 0.034*** | 0.029*** | 0.013 | 0.006 |
| New sanction cases after a conflict year | 0.045** | 0.080*** | 0.130*** | 0.069*** | 0.067*** | 0.025 | 0.020 |

The raw version (in `empirical_response.md`) has the same shape at a much higher level (e.g. conflict after a
sanction 0.17–0.20 at every horizon), i.e. mostly the permanent difference between sanctioned and other states.

## Meaning

- **Violence around a sanction:** violence is already elevated two years before (h = −2), rises further, **peaks
  in the sanction year**, and is back near the state's normal level two years later (h = 2: +0.020, n.s.).
  Sanctions arrive at the peak of an escalation.
- **Sanctions around a conflict year:** the sanction probability rises in the year before, peaks in the
  conflict year and stays elevated for two more years. Senders react to conflict quickly and keep reacting.
- **Link to the VAR:** the decline of violence after the peak is what produces the negative t−2 coefficient in
  Table 1 (04). The response function cannot tell whether that decline is an effect of the sanction or the end of
  the escalation that prompted it; the VAR conditions on past violence and is the better guide to that. Both
  are limited by annual data: what happens within the sanction year cannot be ordered.
- Like JP's Figure 2, these are correlations conditional on nothing but fixed effects; they describe the
  pattern the VAR has to fit.

The LP-DiD event study (formerly part B here) is now an extension in script 12, see `12_lpdid.md`.
