# 12 — LP-DiD event study (EXTENSION, not part of the Jaeger & Paserman base case)

Script: `empirics/scripts/12_lpdid.R` · Output: `results/tables/lpdid.md`, `lpdid_event_study.csv`,
`gdelt_lpdid_event_study.csv`, `results/figures/fig11_lpdid_event_study.png`, `fig16_gdelt_lpdid_event_study.png`.
Moved out of script 07 on 2026-10-22: the base case follows Jaeger & Paserman; LP-DiD is not yet a confirmed
part of the project. Numbers: run of 2026-10-21 (UCDP) and 2026-10-22 (GDELT); unchanged by the move.

**Method** (Dube, Girardi, Jordà & Taylor 2023): compares states with an event to "clean" controls (no event in
that year or the three years before), with the outcome measured as the change since the year before the event
(t−1); year effects, and two lags of the outcome from h = 0 on. Events: a new sanction after three years without
one; a conflict onset after three peaceful years. Pre-event horizons (h = −3, −2) test whether treated and
control states were already on different paths.

## UCDP

| Outcome after event | h = −3 | h = −2 | h = 0 | h = 1 | h = 2 | h = 3 | h = 5 | Events |
|---|---|---|---|---|---|---|---|---|
| Conflict after a new sanction | −0.002 | 0.012 | 0.086*** | 0.080*** | 0.063*** | 0.040* | 0.033 | 348 |
| log deaths after a new sanction | −0.020 | 0.004 | 0.230*** | 0.199*** | 0.119** | 0.108** | 0.103** | 348 |
| New sanction after a conflict onset | 0.004 | −0.005 | 0.128*** | 0.065* | 0.124*** | 0.038 | 0.107*** | 111 |
| New sanction cases after a conflict onset | 0.032 | 0.002 | 0.427*** | 0.148* | 0.261*** | 0.040 | 0.253** | 111 |

- Pre-trends are flat for UCDP.
- After a new sanction, violence is higher than in clean controls (+8.6 pp conflict probability in the sanction
  year). Not evidence that sanctions cause violence: the h = 0 change includes escalation within the year that
  may have triggered the sanction, and clean controls are states senders did not target.
- After a conflict onset, new sanctions follow (+12.8 pp in the onset year).

## GDELT (both windows)

- Violent share up 0.8–1.1 pp in the years after a new sanction; pre-trends flat.
- No sanction response after a GDELT violence onset, and non-zero pre-trends (h = −2 significantly negative),
  so the comparison is not credible in that direction with the median-based GDELT incidence measure.

## How it relates to the base case

The VAR (04, 08) asks whether sanctions predict deviations from the violence path *given past violence*; with
controls it finds a small reduction in conflict two years later. LP-DiD shows the path relative to untreated
states, dominated by the escalation around the sanction. The two are not contradictory, but they answer
different questions; whether LP-DiD enters the paper is open.
