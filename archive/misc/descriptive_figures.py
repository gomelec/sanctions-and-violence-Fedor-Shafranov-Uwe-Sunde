"""
descriptive_figures.py
Descriptive figures of the analysis panel (no treatment x outcome relationships:
sanctions and violence are described separately, so the figures do not pre-empt the
choice of the main specification).

Input : data/processed/sanctions_violence/sanctions_violence_panel.csv
Output: empirics/results/figures/descriptives/fig1..fig5 (.png)
"""
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "empirics" / "results" / "figures" / "descriptives"
OUT.mkdir(parents=True, exist_ok=True)

# palette (reference categorical slots, light mode) and text tokens
C = {"blue": "#2a78d6", "orange": "#eb6834", "aqua": "#1baf7a", "yellow": "#eda100",
     "violet": "#6250d6", "red": "#e34948"}
INK, INK2, MUTED, GRID, SURF = "#0b0b0b", "#52514e", "#8a8984", "#e6e5e1", "#fcfcfb"
SEQ = matplotlib.colors.LinearSegmentedColormap.from_list("blues", ["#f2f6fc", "#9cc0ef", "#2a78d6", "#123c75"])
SEQ.set_bad("#d9d8d3")      # missing / state not in the system

plt.rcParams.update({
    "figure.facecolor": SURF, "axes.facecolor": SURF, "savefig.facecolor": SURF,
    "font.size": 10, "axes.edgecolor": GRID, "axes.labelcolor": INK2, "xtick.color": INK2,
    "ytick.color": INK2, "axes.titlesize": 12, "axes.titleweight": "bold", "axes.titlecolor": INK,
    "axes.titlelocation": "left", "axes.spines.top": False, "axes.spines.right": False,
    "axes.grid": True, "grid.color": GRID, "grid.linewidth": 0.8, "axes.axisbelow": True,
    "lines.linewidth": 2, "legend.frameon": False,
})


def note(fig, text):
    fig.text(0.01, -0.03, text, color=MUTED, fontsize=8, ha="left", va="top")


def save(fig, name):
    fig.savefig(OUT / name, dpi=200, bbox_inches="tight")
    plt.close(fig)
    print("Wrote", OUT / name)


p = pd.read_csv(ROOT / "data" / "processed" / "sanctions_violence" / "sanctions_violence_panel.csv")
p["yr"] = p["year"].str[:4].astype(int)

# ---------------------------------------------------------------------------
# Fig 1: share of states under sanctions, by imposing actor
# ---------------------------------------------------------------------------
s = p.groupby("yr")[["any_sanction", "us_sanction", "eu_sanction", "un_sanction", "ru_sanction"]].mean() * 100
fig, ax = plt.subplots(figsize=(8, 4.5))
series = [("any_sanction", "Any sanction", C["blue"]), ("us_sanction", "United States", C["orange"]),
          ("eu_sanction", "EU / EEC", C["aqua"]), ("un_sanction", "UN", C["violet"]),
          ("ru_sanction", "Russia / USSR", C["yellow"])]
end_y = {col: s[col].iloc[-1] for col, _, _ in series}
order = sorted(end_y, key=end_y.get)                       # spread end labels at least 4.5 points apart
placed = {}
for col in order:
    y = end_y[col]
    if placed and y - max(placed.values()) < 4.5:
        y = max(placed.values()) + 4.5
    placed[col] = y
for col, lab, col_c in series:
    ax.plot(s.index, s[col], color=col_c, label=lab)
    ax.annotate(lab, (s.index[-1], placed[col]), xytext=(6, 0), textcoords="offset points",
                color=INK2, va="center", fontsize=9)
ax.set_xlim(1950, 2031)
ax.set_ylim(0, 100)
ax.set_ylabel("% of states targeted")
ax.set_title("The rise of sanctions: share of states under at least one sanction")
ax.legend(loc="upper left", ncols=5, fontsize=9)
# group cases that GSDB expands to all members (data/README.md, S10)
ax.annotate("2002–08: US aid cut to ICC members\n(case 685, coded for 108 states)", (2002, 77), xytext=(1984, 68),
            fontsize=8, color=INK2, ha="center", arrowprops=dict(arrowstyle="-", color=MUTED, lw=0.8))
ax.annotate("2014: Russian counter-sanctions\non EU members (case 995)", (2013.6, 17), xytext=(1988, 13.5),
            fontsize=8, color=INK2, ha="center", arrowprops=dict(arrowstyle="-", color=MUTED, lw=0.8))
ax.annotate("1976: US anti-boycott measures\nvs Arab League members (case 199)", (1976.5, 30), xytext=(1962, 52),
            fontsize=8, color=INK2, ha="center", arrowprops=dict(arrowstyle="-", color=MUTED, lw=0.8))
note(fig, "Source: GSDB v4 (case-based measures), Gleditsch–Ward states 1950–2023. Own calculations.")
save(fig, "fig1_share_sanctioned_by_actor.png")

# ---------------------------------------------------------------------------
# Fig 2: senders vs cases — what num_sanctioners actually measures
# ---------------------------------------------------------------------------
q = p[p["any_sanction"] == 1]
fig, ax = plt.subplots(figsize=(8, 4.8))
for un, lab, col_c in [(0, "No UN case", C["blue"]), (1, "At least one UN case", C["orange"])]:
    d = q[q["un_sanction"] == un]
    jitter = np.random.default_rng(1).uniform(-0.25, 0.25, len(d))
    ax.scatter(d["n_cases_received"] + jitter, d["num_sanctioners"], s=14, color=col_c, alpha=0.45,
               edgecolors=SURF, linewidths=0.4, label=lab)
ax.set_xlabel("Number of sanction cases against the state (n_cases_received)")
ax.set_ylabel("Number of sanctioning countries (num_sanctioners)")
ax.set_title("Sender counts jump to ~190 whenever the UN acts")
ax.legend(loc="center right", fontsize=9)
note(fig, "Each dot is a sanctioned state-year (1950–2023), horizontal jitter added. GSDB codes UN cases as one row per member state.")
save(fig, "fig2_senders_vs_cases.png")

# ---------------------------------------------------------------------------
# Fig 3: organized-violence deaths by type, world total
# ---------------------------------------------------------------------------
v = p[p["yr"] >= 1989].groupby("yr")[["sb_total_deaths_best", "ns_total_deaths_best", "os_total_deaths_best"]].sum() / 1000
fig, ax = plt.subplots(figsize=(8, 4.5))
for col, lab, col_c in [("sb_total_deaths_best", "State-based conflict", C["blue"]),
                        ("ns_total_deaths_best", "Non-state conflict", C["aqua"]),
                        ("os_total_deaths_best", "One-sided violence", C["orange"])]:
    ax.plot(v.index, v[col], color=col_c, label=lab)
ax.set_ylabel("Deaths, thousands (best estimate)")
ax.set_title("Organized violence: deaths per year by type of violence")
ax.legend(loc="upper right", fontsize=9)
for yr_, col, txt in [(1994, "os_total_deaths_best", "Rwanda genocide"), (2000, "sb_total_deaths_best", "Ethiopia–Eritrea"),
                      (2014, "sb_total_deaths_best", "Syria, Iraq"), (2022, "sb_total_deaths_best", "Ethiopia (Tigray), Ukraine")]:
    ax.annotate(txt, (yr_, v.at[yr_, col]), xytext=(0, 8), textcoords="offset points", ha="center", fontsize=8.5, color=INK2)
ax.set_ylim(0, v.max().max() * 1.12)
note(fig, "Source: UCDP Organized Violence Country-Year v26.1, summed over Gleditsch–Ward states. Own calculations.")
save(fig, "fig3_violence_deaths_by_type.png")

# ---------------------------------------------------------------------------
# Fig 4: heatmap of the 20 most sanctioned states (case-years), cases per year
# ---------------------------------------------------------------------------
top = p.groupby("gw_name")["n_cases_received"].sum().nlargest(20).index
h = (p[p["gw_name"].isin(top)].pivot_table(index="gw_name", columns="yr", values="n_cases_received")
       .reindex(top))
fig, ax = plt.subplots(figsize=(10, 6))
im = ax.imshow(np.ma.masked_invalid(h.values.astype(float)), aspect="auto", cmap=SEQ, interpolation="nearest")
ax.set_yticks(range(len(h.index)), [n.split(" (")[0] for n in h.index], fontsize=8.5)
yrs = list(h.columns)
ticks = [i for i, y in enumerate(yrs) if y % 10 == 0]
ax.set_xticks(ticks, [yrs[i] for i in ticks])
ax.grid(False)
for sp in ax.spines.values():
    sp.set_visible(False)
cb = fig.colorbar(im, ax=ax, fraction=0.025, pad=0.01)
cb.set_label("Sanction cases in force", color=INK2)
cb.outline.set_visible(False)
ax.set_title("Who is sanctioned, and when: the 20 most-sanctioned states")
note(fig, "Ranking by total case-years 1950–2023. Source: GSDB v4, own calculations. Gray = state not in the system that year.")
save(fig, "fig4_heatmap_most_sanctioned.png")

# ---------------------------------------------------------------------------
# Fig 5: data coverage of the main variables
# ---------------------------------------------------------------------------
cov_vars = [("num_sanctioners", "Sanctions (GSDB)"), ("cumulative_total_deaths_parties_in_orgvio_pc", "Deaths per capita (UCDP)"),
            ("total_violence_norm1000", "Conflict events (GDELT)"), ("v2x_polyarchy", "Democracy (V-Dem)"),
            ("gdp_ext", "GDP per capita"), ("pop_ext", "Population")]
cov = pd.DataFrame({lab: p.groupby("yr")[v_].apply(lambda x: x.notna().mean() * 100) for v_, lab in cov_vars}).T
fig, ax = plt.subplots(figsize=(10, 3.4))
im = ax.imshow(cov.values.astype(float), aspect="auto", cmap=SEQ, vmin=0, vmax=100, interpolation="nearest")
ax.set_yticks(range(len(cov.index)), cov.index, fontsize=9)
yrs = list(cov.columns)
ticks = [i for i, y in enumerate(yrs) if y % 10 == 0]
ax.set_xticks(ticks, [yrs[i] for i in ticks])
ax.grid(False)
for sp in ax.spines.values():
    sp.set_visible(False)
cb = fig.colorbar(im, ax=ax, fraction=0.025, pad=0.01)
cb.set_label("% of states with data", color=INK2)
cb.outline.set_visible(False)
ax.set_title("Where the data are: coverage of the main variables")
note(fig, "Share of Gleditsch–Ward states with a non-missing value, by year. UCDP starts 1989, GDELT covers 1979–2021.")
save(fig, "fig5_data_coverage.png")
