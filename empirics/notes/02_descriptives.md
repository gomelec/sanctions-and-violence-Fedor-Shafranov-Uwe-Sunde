# 02 — Descriptives

Script: `empirics/scripts/02_descriptives.R` · Output: `results/figures/descriptives/fig1–fig9`,
`results/tables/tab_sanction_flows_summary.csv`. Purely descriptive: sanctions and violence are shown separately.

| Figure | Shows | What to look for |
|---|---|---|
| fig1 share sanctioned by actor | Share of states under a sanction (stock), by sender | Expansion of sanction coverage over time; the US as the most frequent sender |
| fig2 senders vs cases | Number of sender countries vs number of cases | Whether many senders act together (EU/UN cases) or alone |
| fig3 violence deaths by type | Conflict deaths by violence type | The peaks (Rwanda 1994, Syria mid-2010s) behind the skewed deaths variable |
| fig4 heatmap most sanctioned | Sanction cases over time for the most sanctioned states | How concentrated and persistent sanctions are |
| fig5 data coverage | Years covered by each source | Why the window is 1989–2019 |
| fig6 new / lifted cases per year | New and lifted GSDB cases (flows, decision S11) | Waves of new cases |
| fig7 share new sanction by actor | Share of states receiving a new sanction, by sender | US ≈ 6% of state-years, EU 2%, UN 1% (table below) |
| fig8 variation new sanctions | Within- vs between-state variation of new sanctions | Whether FE leave enough variation |
| fig9 new sanctions by type/decade | New sanctions by type and objective per decade | Changing composition (arms, conflict-related objectives) |

**Sanction flows, 1989–2019 (`tab_sanction_flows_summary.csv`).**
- 55% of state-years are under at least one sanction (stock), but only 10.9% receive a *new* one (flow).
- 167 states receive at least one new case. New UN cases are rare (1.2%, 29 states), EU 2.1% (66), US 5.9%
  (155). Lifting events: 9.3% of state-years.

**Why it matters.** The stock is persistent and covers half the sample, so it cannot serve as an impulse. The
*new-sanction* flow is the variable that moves, and it is used in the VAR (this is the reason for constructing
the GSDB flow variables). The thinness of UN and EU flows limits the planned split by sender (script 09).
