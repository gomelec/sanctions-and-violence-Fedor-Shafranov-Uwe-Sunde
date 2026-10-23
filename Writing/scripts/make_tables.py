"""
make_tables.py — LaTeX tables for the advisor brief (Writing/main.tex) from the
CSV results of the empirics scripts.

Run from the project folder after the empirics (or via master.py, step "writing_tables"):
    uv run python Writing/scripts/make_tables.py

Every table is written to Writing/tables/<name>.tex and pulled into main.tex with
\\input{tables/<name>}. The tables therefore always show the numbers of the latest
run; only the numbers quoted in the text of main.tex have to be checked by hand.

Input : empirics/results/tables/*.csv
Output: Writing/tables/*.tex
"""
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parents[2]
RESULTS = ROOT / "empirics" / "results" / "tables"
OUT = ROOT / "Writing" / "tables"
OUT.mkdir(parents=True, exist_ok=True)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def read(name: str) -> pd.DataFrame:
    return pd.read_csv(RESULTS / f"{name}.csv")


def stars(p: float) -> str:
    """Significance stars as LaTeX superscript."""
    if pd.isna(p):
        return ""
    if p < 0.01:
        return "$^{***}$"
    if p < 0.05:
        return "$^{**}$"
    if p < 0.10:
        return "$^{*}$"
    return ""


def p_text(p: float) -> str:
    """p-value for display: '<0.001' or three decimals."""
    return "$<$0.001" if p < 0.001 else f"{p:.3f}"


def num(x: float, digits: int = 3) -> str:
    """Number with a proper minus sign."""
    text = f"{x:.{digits}f}"
    return text.replace("-", "$-$")


def write(name: str, lines: list[str]) -> None:
    (OUT / f"{name}.tex").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"wrote Writing/tables/{name}.tex")


def table(caption: str, label: str, colspec: str, body: list[str], notes: str, size: str = "\\small") -> list[str]:
    """Standard table frame: booktabs + threeparttable notes."""
    return [
        "\\begin{table}[htbp]", "\\centering", size,
        f"\\caption{{{caption}}}", f"\\label{{{label}}}",
        "\\begin{threeparttable}",
        f"\\begin{{tabular}}{{{colspec}}}", "\\toprule",
        *body,
        "\\bottomrule", "\\end{tabular}",
        "\\begin{tablenotes}[flushleft]\\footnotesize", f"\\item \\textit{{Notes:}} {notes}", "\\end{tablenotes}",
        "\\end{threeparttable}", "\\end{table}",
    ]


SPEC_LABEL = {"incidence": "Incidence", "levels": "Levels"}
CONTROL_LABEL = {"with_controls": "with controls", "no_controls": "FE only"}
DIRECTION = {"violence": "Sanctions $\\rightarrow$ violence", "sender": "Violence $\\rightarrow$ sanctions"}


# ---------------------------------------------------------------------------
# 1. Descriptive statistics
# ---------------------------------------------------------------------------
def descriptives() -> None:
    labels = {
        "new_sanction": "New sanction (0/1)",
        "n_new_cases": "Number of new sanction cases",
        "viol_inc": "Conflict, $\\geq$ 25 deaths (0/1)",
        "viol_lev": "$\\log(1 + \\text{deaths per 100,000})$",
        "deaths_pc": "Deaths per 100,000 (raw)",
        "ctrl_stock": "Sanction cases in force, $t-1$",
        "ctrl_gdp_growth": "GDP per capita growth, $t-1$",
        "ctrl_democracy": "V-Dem polyarchy, $t-1$",
    }
    data = read("sample_summary")
    body = ["Variable & Mean & SD & $N$ \\\\", "\\midrule"]
    for _, row in data.iterrows():
        body.append(f"{labels.get(row.variable, row.variable)} & {num(row['mean'])} & {num(row.sd)} & {int(row.n):,} \\\\")
    write("tab_descriptives", table(
        "Descriptive statistics, 1989--2019", "tab:descriptives", "lrrr", body,
        "State-years of the estimation panel (197 states, 1989--2019). Sanctions: Global Sanctions Data Base "
        "(GSDB, release 4), flows of new cases constructed from case start years. Violence: UCDP organized "
        "violence, country-year (v26.1). Controls are lagged one year; missing controls are mostly microstates "
        "without V-Dem data."))


# ---------------------------------------------------------------------------
# 2. Granger tests by estimator (main results table)
# ---------------------------------------------------------------------------
def granger() -> None:
    ols = read("table1_granger")
    gmm = read("gmm_granger")
    tests = pd.concat([ols, gmm], ignore_index=True)
    columns = [("OLS", "with_controls"), ("OLS", "no_controls"),
               ("jackknife", "with_controls"), ("jackknife", "no_controls"),
               ("GMM", "with_controls"), ("GMM", "no_controls")]

    def cell(equation, spec, estimator, controls, what):
        row = tests[(tests.equation == equation) & (tests.specification == spec)
                    & (tests.estimator == estimator) & (tests.control_set == controls)].iloc[0]
        if what == "chi2":
            return f"{row.chi2:.2f}{stars(row.p_value)}"
        if what == "p":
            return f"({p_text(row.p_value)})"
        return f"[{num(row.sum_cross_lags)}]"

    body = [" & \\multicolumn{2}{c}{FE-OLS} & \\multicolumn{2}{c}{Half-panel jackknife} & \\multicolumn{2}{c}{GMM} \\\\",
            "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}\\cmidrule(lr){6-7}",
            " & Controls & FE only & Controls & FE only & Controls & FE only \\\\", "\\midrule"]
    for panel, equation in [("A", "violence"), ("B", "sender")]:
        body.append(f"\\multicolumn{{7}}{{l}}{{\\textit{{Panel {panel}: {DIRECTION[equation]}}}}} \\\\")
        for spec in ["incidence", "levels"]:
            for what, label in [("chi2", SPEC_LABEL[spec]), ("p", ""), ("sum", "")]:
                cells = [cell(equation, spec, est, ctl, what) for est, ctl in columns]
                body.append(f"\\quad {label} & " + " & ".join(cells) + " \\\\")
        if panel == "A":
            body.append("\\midrule")
    # sample sizes (incidence violence equation; identical across equations of one VAR)
    sizes = tests[(tests.equation == "violence") & (tests.specification == "incidence")]
    obs, states = [], []
    for estimator, controls in columns:
        r = sizes[(sizes.estimator == estimator) & (sizes.control_set == controls)].iloc[0]
        obs.append(f"{int(r.n_obs):,}")
        states.append(f"{int(r.n_states)}")
    body += ["\\midrule",
             "Observations & " + " & ".join(obs) + " \\\\",
             "States & " + " & ".join(states) + " \\\\"]
    write("tab_granger", table(
        "Granger causality tests: panel version of Jaeger and Paserman (2008), Table 1", "tab:granger",
        "lcccccc", body,
        "Wald $\\chi^2(2)$ statistic for the joint significance of the two lags of the other variable in a "
        "bivariate panel VAR(2) with state and year fixed effects; $p$-value in parentheses; sum of the two lag "
        "coefficients in brackets (negative in Panel A = less violence after new sanctions). Incidence: new "
        "sanction (0/1) and conflict with $\\geq$ 25 deaths (0/1), linear probability models. Levels: number of new "
        "cases and $\\log(1+$deaths per 100,000$)$. Controls (lagged): sanction stock, GDP per capita growth, V-Dem "
        "polyarchy, ex-Yugoslavia dummy. FE-OLS and jackknife: standard errors clustered by state; jackknife = "
        "$2\\hat\\beta - (\\hat\\beta_{1991-2005} + \\hat\\beta_{2006-2019})/2$ \\citep{dhaene2015}. GMM: forward "
        "orthogonal deviations, collapsed instruments (lags 2--5), year-demeaned; its Wald test ignores the "
        "covariance of the two lag coefficients (approximate). 1991--2019. $^{*}p<0.1$, $^{**}p<0.05$, $^{***}p<0.01$.",
        size="\\footnotesize"))


# ---------------------------------------------------------------------------
# 3. Full coefficients (appendix): JP Table 1 layout, OLS
# ---------------------------------------------------------------------------
def coefficients() -> None:
    coef = read("table1_coefficients")
    coef = coef[coef.estimator == "OLS"]
    columns = [("incidence", "sender"), ("levels", "sender"), ("incidence", "violence"), ("levels", "violence")]
    variables = {"incidence": {"sanction": "new_sanction", "violence": "viol_inc"},
                 "levels": {"sanction": "n_new_cases", "violence": "viol_lev"}}
    controls = {"ctrl_stock": "Sanction stock", "ctrl_gdp_growth": "GDP growth",
                "ctrl_democracy": "Democracy", "ex_yugo_1991_2016": "Ex-Yugoslavia"}

    def cells(control_set, term_of):
        estimates, errors = [], []
        for spec, equation in columns:
            term = term_of(spec)
            row = coef[(coef.specification == spec) & (coef.equation == equation)
                       & (coef.control_set == control_set) & (coef.term == term)]
            if row.empty:
                estimates.append(""); errors.append("")
            else:
                r = row.iloc[0]
                estimates.append(f"{num(r.estimate)}{stars(r.p_value)}")
                errors.append(f"({r.std_error:.3f})")
        return estimates, errors

    body = [" & \\multicolumn{2}{c}{Sender equation} & \\multicolumn{2}{c}{Violence equation} \\\\",
            "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}",
            "Dependent variable & New sanction & New cases & Conflict & log deaths \\\\", "\\midrule"]
    for control_set, title in [("with_controls", "A. With lagged controls"), ("no_controls", "B. State and year FE only")]:
        body.append(f"\\multicolumn{{5}}{{l}}{{\\textit{{{title}}}}} \\\\")
        for kind, label in [("violence", "Violence"), ("sanction", "New sanctions")]:
            for k in (1, 2):
                est, err = cells(control_set, lambda spec: f"{variables[spec][kind]}_l{k}")
                body.append(f"\\quad {label}, $t-{k}$ & " + " & ".join(est) + " \\\\")
                body.append(" & " + " & ".join(err) + " \\\\")
        if control_set == "with_controls":
            for term, label in controls.items():
                est, err = cells(control_set, lambda spec: term)
                body.append(f"\\quad {label}, $t-1$ & " + " & ".join(est) + " \\\\")
                body.append(" & " + " & ".join(err) + " \\\\")
            body.append("\\midrule")
    write("tab_coefficients", table(
        "Reaction functions (FE-OLS): all coefficients", "tab:coefficients", "lcccc", body,
        "Bivariate panel VAR(2), equation by equation, state and year fixed effects, standard errors clustered by "
        "state in parentheses. Columns (1)--(2): new sanctions on lags of violence and of new sanctions; "
        "(3)--(4): violence on lags of violence and of new sanctions. 1991--2019. "
        "$^{*}p<0.1$, $^{**}p<0.05$, $^{***}p<0.01$.", size="\\footnotesize"))


# ---------------------------------------------------------------------------
# 4. Lag grid (appendix): JP Table 2
# ---------------------------------------------------------------------------
def lag_grid() -> None:
    grid = read("table2_lag_grid")
    grid = grid[grid.estimator == "OLS"]
    columns = [("sender", "incidence"), ("sender", "levels"), ("violence", "incidence"), ("violence", "levels")]
    body = [" & \\multicolumn{2}{c}{Violence $\\rightarrow$ sanctions} & \\multicolumn{2}{c}{Sanctions $\\rightarrow$ violence} \\\\",
            "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}",
            "Lags (own, other) & Incidence & Levels & Incidence & Levels \\\\", "\\midrule"]
    for control_set, title in [("with_controls", "A. With lagged controls"), ("no_controls", "B. State and year FE only")]:
        body.append(f"\\multicolumn{{5}}{{l}}{{\\textit{{{title}}}}} \\\\")
        part = grid[grid.control_set == control_set]
        for other in (1, 2, 3):
            for own in (1, 2, 3):
                cells = []
                for equation, spec in columns:
                    r = part[(part.equation == equation) & (part.specification == spec)
                             & (part.own_lags == own) & (part.other_lags == other)].iloc[0]
                    dagger = "$^{\\dagger}$" if str(r.lowest_bic).upper() == "TRUE" else ""
                    cells.append(f"{p_text(r.p_value)}{stars(r.p_value)}{dagger}")
                body.append(f"\\quad ({own}, {other}) & " + " & ".join(cells) + " \\\\")
        if control_set == "with_controls":
            body.append("\\midrule")
    write("tab_lag_grid", table(
        "Granger tests for different lag structures: panel version of Jaeger and Paserman (2008), Table 2",
        "tab:laggrid", "lcccc", body,
        "$p$-values of the Granger test (FE-OLS, clustered by state) for every combination of own lags and lags of "
        "the other variable; common sample with three lags of both variables (1992--2019), so that BIC is "
        "comparable. $^{\\dagger}$ lowest BIC in the column. $^{*}p<0.1$, $^{**}p<0.05$, $^{***}p<0.01$.",
        size="\\footnotesize"))


# ---------------------------------------------------------------------------
# 5. Data diagnostics: unit roots and persistence
# ---------------------------------------------------------------------------
def data_diagnostics() -> None:
    roots = read("diag_unit_root")
    roots = roots[roots.version == "raw"].set_index("variable")
    persistence = read("diag_persistence").set_index("variable")
    labels = {"new_sanction": "New sanction (0/1)", "n_new_cases": "New sanction cases",
              "viol_inc": "Conflict (0/1)", "viol_lev": "log deaths per 100k"}
    body = [" & \\multicolumn{4}{c}{Unit-root tests} & \\multicolumn{3}{c}{Persistence} \\\\",
            "\\cmidrule(lr){2-5}\\cmidrule(lr){6-8}",
            "Series & \\makecell{States\\\\tested} & \\makecell{Share\\\\rejecting} & \\makecell{Maddala--Wu,\\\\Choi $p$} "
            "& \\makecell{CIPS\\\\(states)} & \\makecell{FE AR(1),\\\\corrected} & \\makecell{P(1$|$0)} & \\makecell{P(1$|$1)} \\\\",
            "\\midrule"]
    for variable, label in labels.items():
        r, q = roots.loc[variable], persistence.loc[variable]
        p_on_off = "" if pd.isna(q.p_on_given_off) else f"{q.p_on_given_off:.3f}"
        p_on_on = "" if pd.isna(q.p_on_given_on) else f"{q.p_on_given_on:.3f}"
        combined = max(r.maddala_wu_p, r.choi_p)
        body.append(f"{label} & {int(r.states_tested)} & {r.share_reject_5pct:.2f} & {p_text(combined)} & "
                    f"{num(r.cips, 2)} ({int(r.cips_states)}) & {q.fe_ar1_nickell_corrected:.2f} & {p_on_off} & {p_on_on} \\\\")
    write("tab_data_diagnostics", table(
        "Stationarity and persistence of the VAR variables", "tab:datadiag", "lccccccc", body,
        "Unit-root tests, H$_0$: unit root in every state. State ADF regressions with intercept, 0--2 lagged "
        "differences by AIC; Maddala--Wu and Choi combine the state $p$-values (larger of the two shown); CIPS "
        "\\citep{pesaran2007} adds cross-section averages against common shocks, balanced sub-panel, all "
        "$p<0.01$. Only states whose series varies can be tested (constant series, e.g.\\ never in conflict, "
        "are trivially stationary and stay in the sample). Persistence: FE AR(1) with state and year effects plus "
        "the Nickell correction $(1+\\rho)/(T-1)$; P(1$|$0), P(1$|$1): probability of a 1 given last year's value. "
        "1989--2019.", size="\\footnotesize"))


# ---------------------------------------------------------------------------
# 6. Model diagnostics
# ---------------------------------------------------------------------------
def model_diagnostics() -> None:
    autocorrelation = read("diag_residual_autocorrelation")
    dependence = read("diag_cross_section_dependence")
    dependence = dependence[dependence.states_used == "outcome varies"]
    stability = read("diag_stability")
    body = [" & & \\multicolumn{2}{c}{Residual autocorr., $p$} & \\multicolumn{2}{c}{Pesaran CD} & \\multicolumn{3}{c}{Largest root} \\\\",
            "\\cmidrule(lr){3-4}\\cmidrule(lr){5-6}\\cmidrule(lr){7-9}",
            "Model & Equation & Lag 1 & Lag 2 & \\makecell{Mean\\\\corr.} & $p$ & OLS & JK & GMM \\\\", "\\midrule"]
    for spec in ["incidence", "levels"]:
        for controls in ["with_controls", "no_controls"]:
            model = f"{spec}_{controls}"
            roots = stability[(stability.specification == spec) & (stability.control_set == controls)].set_index("estimator").largest_root
            for i, equation in enumerate(["violence", "sender"]):
                ac = autocorrelation[(autocorrelation.model == model) & (autocorrelation.equation == equation)].set_index("lag").p_value
                cd = dependence[(dependence.model == model) & (dependence.equation == equation)].iloc[0]
                name = f"{SPEC_LABEL[spec]}, {CONTROL_LABEL[controls]}" if i == 0 else ""
                root_cells = (f"{roots['OLS']:.2f} & {roots['jackknife']:.2f} & {roots['GMM']:.2f}" if i == 0 else " & & ")
                body.append(f"{name} & {equation.capitalize()} & {p_text(ac[1])} & {p_text(ac[2])} & "
                            f"{num(cd.mean_correlation)} & {p_text(cd.p_value)} & {root_cells} \\\\")
    write("tab_model_diagnostics", table(
        "Diagnostics of the estimated VARs", "tab:modeldiag", "llccccccc", body,
        "Residual autocorrelation: regression of the FE residual on its own lag, tested against the value "
        "$-1/(T-1)$ implied by within-demeaning \\citep[section 10.5.4]{wooldridge2010}. Pesaran CD "
        "\\citep{pesaran2015}: states whose dependent variable varies (constant-outcome states have mechanically "
        "identical residuals); mean pairwise residual correlation and $p$-value. Largest root: modulus of the "
        "largest eigenvalue of the companion matrix (stable if $<1$), FE-OLS, half-panel jackknife (JK) and GMM.",
        size="\\footnotesize"))


# ---------------------------------------------------------------------------
# 7. Cumulative impulse responses
# ---------------------------------------------------------------------------
def irf() -> None:
    irf = read("irf_results")
    irf = irf[(irf.horizon == 10) & (irf.shock != irf.response)]
    identifications = ["simple", "cholesky_sanction_first", "cholesky_violence_first"]
    body = [" & & \\makecell{No same-year\\\\effect} & \\makecell{Cholesky,\\\\sanctions first} & \\makecell{Cholesky,\\\\violence first} \\\\",
            "\\midrule"]
    for shock, title in [("sanction", "Shock: new sanction; response: violence"), ("violence", "Shock: violence; response: new sanctions")]:
        body.append(f"\\multicolumn{{5}}{{l}}{{\\textit{{{title}}}}} \\\\")
        for spec in ["incidence", "levels"]:
            for controls in ["with_controls", "no_controls"]:
                cells = []
                for identification in identifications:
                    r = irf[(irf.shock == shock) & (irf.specification == spec) & (irf.control_set == controls)
                            & (irf.identification == identification)].iloc[0]
                    significant = r.cumulative_lower > 0 or r.cumulative_upper < 0
                    mark = "$^{\\ast}$" if significant else ""
                    cells.append(f"\\makecell{{{num(r.cumulative)}{mark}\\\\{{\\scriptsize[{num(r.cumulative_lower)}, {num(r.cumulative_upper)}]}}}}")
                body.append(f"\\quad {SPEC_LABEL[spec]} & {CONTROL_LABEL[controls]} & " + " & ".join(cells) + " \\\\")
        if shock == "sanction":
            body.append("\\midrule")
    draws = int(read("irf_results").bootstrap_draws.iloc[0])
    write("tab_irf", table(
        "Cumulative impulse responses after ten years", "tab:irf", "llccc", body,
        "Sum of the responses over years 0--10 to a one-unit shock (one new sanction / one conflict year in the "
        "incidence VAR; one new case / one unit of $\\log(1+$deaths per 100,000$)$ in the levels VAR). 95\\% "
        f"country-cluster bootstrap intervals in brackets ({draws} draws); $^{{\\ast}}$ interval excludes zero. "
        "No same-year effect: the identification of \\citet[fn.~12]{jaeger2008}; Cholesky orderings allow a "
        "same-year effect in one direction (rescaled to a unit own shock). For a sanction shock, ``no same-year "
        "effect'' coincides with ``violence first''; for a violence shock, with ``sanctions first''.",
        size="\\footnotesize"))


# ---------------------------------------------------------------------------
# 8. GMM diagnostics
# ---------------------------------------------------------------------------
def gmm_diagnostics() -> None:
    gmm = read("gmm_granger")
    gmm = gmm[gmm.equation == "violence"]
    body = ["Specification & States & Obs. & Moments & Hansen $J$ (df) & $p$ & Largest root \\\\", "\\midrule"]
    for spec in ["incidence", "levels"]:
        for controls in ["with_controls", "no_controls"]:
            r = gmm[(gmm.specification == spec) & (gmm.control_set == controls)].iloc[0]
            body.append(f"{SPEC_LABEL[spec]}, {CONTROL_LABEL[controls]} & {int(r.n_states)} & {int(r.n_obs):,} & "
                        f"{int(r.n_moment_conditions)} & {r.hansen_j:.2f} ({int(r.hansen_df)}) & {p_text(r.hansen_p)} & {r.largest_root:.2f} \\\\")
    write("tab_gmm", table(
        "GMM panel VAR: specification tests", "tab:gmm", "lcccccc", body,
        "Two-step GMM with forward orthogonal deviations and collapsed instruments (lags 2--5), variables "
        "demeaned by year \\citep{abrigo2016}. Hansen $J$: H$_0$ instruments valid \\citep{hansen1982}; the "
        "number of moment conditions stays well below the number of states \\citep{roodman2009}."))


# ---------------------------------------------------------------------------
# 9. GDELT robustness
# ---------------------------------------------------------------------------
def gdelt() -> None:
    gdelt = read("gdelt_granger")
    ucdp = read("table1_granger")
    samples = [("ucdp_years", "OLS"), ("full_gdelt", "OLS"), ("ucdp_years_thick", "OLS"), ("ucdp_years", "jackknife")]

    def fmt(r):
        return f"\\makecell{{{r.chi2:.2f}{stars(r.p_value)}\\\\{{\\scriptsize [{num(r.sum_cross_lags)}]}}}}"

    body = [" & & UCDP & \\multicolumn{4}{c}{GDELT} \\\\", "\\cmidrule(lr){3-3}\\cmidrule(lr){4-7}",
            " & & \\makecell{1991--2019\\\\OLS} & \\makecell{1991--2019\\\\OLS} & \\makecell{1981--2021\\\\OLS} "
            "& \\makecell{$\\geq$100 events\\\\OLS} & \\makecell{1991--2019\\\\jackknife} \\\\", "\\midrule"]
    for equation in ["violence", "sender"]:
        body.append(f"\\multicolumn{{7}}{{l}}{{\\textit{{{DIRECTION[equation]}}}}} \\\\")
        for spec in ["incidence", "levels"]:
            for controls in ["with_controls", "no_controls"]:
                u = ucdp[(ucdp.equation == equation) & (ucdp.specification == spec) & (ucdp.control_set == controls)
                         & (ucdp.estimator == "OLS")].iloc[0]
                cells = [fmt(u)]
                for sample, estimator in samples:
                    g = gdelt[(gdelt["sample"] == sample) & (gdelt.equation == equation) & (gdelt.specification == spec)
                              & (gdelt.control_set == controls) & (gdelt.estimator == estimator)].iloc[0]
                    cells.append(fmt(g))
                body.append(f"\\quad {SPEC_LABEL[spec]} & {CONTROL_LABEL[controls]} & " + " & ".join(cells) + " \\\\")
        if equation == "violence":
            body.append("\\midrule")
    write("tab_gdelt", table(
        "Robustness: Granger tests with GDELT instead of UCDP violence", "tab:gdelt", "llccccc", body,
        "$\\chi^2(2)$ Granger statistic, sum of the two lag coefficients in brackets. GDELT violence: assault, "
        "fight and mass-violence events per 100 GDELT events in the state-year \\citep{leetaru2013}; incidence = 1 "
        "if above the state's own 1979--2021 median. ``$\\geq$100 events'': state-years with fewer than 100 GDELT "
        "events set to missing. Units differ from UCDP, so compare signs and significance. "
        "$^{*}p<0.1$, $^{**}p<0.05$, $^{***}p<0.01$.", size="\\footnotesize"))

    validation = read("gdelt_validation")
    labels = [
        "Correlation with UCDP log deaths, pooled",
        "Correlation with UCDP log deaths, within states",
        "Correlation with UCDP conflict (0/1), pooled",
        "Correlation with UCDP conflict (0/1), within states",
        "P(GDELT incidence $=1$ $|$ UCDP conflict year)",
        "P(GDELT incidence $=1$ $|$ no UCDP conflict)",
        "P(UCDP conflict $|$ GDELT incidence $=1$)",
    ]
    body = ["Statistic & Value \\\\", "\\midrule"] + [f"{label} & {value:.2f} \\\\" for label, value in zip(labels, validation.value)]
    write("tab_gdelt_validation", table(
        "How closely does GDELT track UCDP violence?", "tab:gdeltvalidation", "lc", body,
        "State-years 1989--2019 with both measures. GDELT measure: violent events in \\% of all GDELT events."))


# ---------------------------------------------------------------------------
# 10. LP-DiD event study (extension, script 12)
# ---------------------------------------------------------------------------
def lpdid() -> None:
    horizons = [-3, -2, 0, 1, 2, 3, 5, 8]
    ucdp = read("lpdid_event_study")
    gdelt_file = RESULTS / "gdelt_lpdid_event_study.csv"
    gdelt = pd.read_csv(gdelt_file) if gdelt_file.exists() else None
    if gdelt is not None:
        gdelt = gdelt[gdelt.window_label.str.startswith("GDELT, 1991")]
    columns = [  # (data, response name, header)
        (ucdp, "violence_after_sanction_incidence", "\\makecell{Conflict\\\\(0/1)}"),
        (ucdp, "violence_after_sanction_levels", "\\makecell{log deaths\\\\per 100k}"),
        (ucdp, "sanctions_after_conflict_incidence", "\\makecell{New sanction\\\\(0/1)}"),
        (ucdp, "sanctions_after_conflict_levels", "\\makecell{New\\\\cases}"),
    ]
    if gdelt is not None:
        columns += [(gdelt, "violence_after_sanction_levels", "\\makecell{Violent share (\\%)\\\\after sanction}"),
                    (gdelt, "sanctions_after_violence_incidence", "\\makecell{New sanction\\\\after onset}")]
    n_ucdp, n_gdelt = 4, len(columns) - 4

    def cell(data, response, h, what):
        r = data[(data.response == response) & (data.horizon == h)].iloc[0]
        if what == "estimate":
            return f"{num(r.estimate)}{stars(r.p_value)}"
        return f"({r.se:.3f})"

    header = (" & \\multicolumn{2}{c}{UCDP: after a new sanction} & \\multicolumn{2}{c}{UCDP: after a conflict onset}"
              + (" & \\multicolumn{2}{c}{GDELT, 1991--2019}" if n_gdelt else "") + " \\\\")
    body = [header,
            "\\cmidrule(lr){2-3}\\cmidrule(lr){4-5}" + ("\\cmidrule(lr){6-7}" if n_gdelt else ""),
            "Horizon $h$ & " + " & ".join(c[2] for c in columns) + " \\\\", "\\midrule"]
    for h in horizons:
        if h == 0:
            body.append("\\midrule")
        body.append(f"{h} & " + " & ".join(cell(d, r, h, "estimate") for d, r, _ in columns) + " \\\\")
        body.append(" & " + " & ".join(cell(d, r, h, "se") for d, r, _ in columns) + " \\\\")
    events = [str(int(d[(d.response == r) & (d.horizon == 0)].iloc[0].events)) for d, r, _ in columns]
    body += ["\\midrule", "Treated events & " + " & ".join(events) + " \\\\"]
    body = [line for line in body if line]
    write("tab_lpdid", table(
        "LP-DiD event study (extension): change in the outcome relative to the year before the event",
        "tab:lpdid", "l" + "c" * len(columns), body,
        "Coefficient on the treatment dummy in $y_{i,t+h}-y_{i,t-1} = \\beta_h D_{it} + \\gamma_h'(y_{i,t-1}, y_{i,t-2}) "
        "+ \\tau_t + e_{it}$ \\citep{dube2023}, estimated on treated state-years (event in $t$, none in the three "
        "previous years) and clean controls (no event in $t$ and the three previous years); lagged outcomes only for "
        "$h\\geq 0$; reference year $h=-1$. Conflict onset: conflict year after three years without conflict; GDELT "
        "violence onset: above-median year after three years at or below the median. GDELT columns 1991--2019. "
        "Standard errors clustered by state. $^{*}p<0.1$, $^{**}p<0.05$, $^{***}p<0.01$.",
        size="\\footnotesize\\setlength{\\tabcolsep}{4pt}"))


# ---------------------------------------------------------------------------
# 11. Nonlinear models: logit and PPML (robustness R3, script 09)
# ---------------------------------------------------------------------------
def nonlinear() -> None:
    file = RESULTS / "robustness_nonlinear.csv"
    if not file.exists():
        print("robustness_nonlinear.csv not found (run 09_robustness.R): table skipped")
        return
    results = pd.read_csv(file)
    ols = read("table1_granger")
    ols = ols[ols.estimator == "OLS"]
    body = [" & & \\multicolumn{2}{c}{Linear (Table~\\ref{tab:granger})} & \\multicolumn{4}{c}{Nonlinear} & \\\\",
            "\\cmidrule(lr){3-4}\\cmidrule(lr){5-8}",
            "Model & Controls & $\\chi^2(2)$ & Sum & $\\chi^2(2)$ & Lag $t-1$ & Lag $t-2$ & \\makecell{Sum, comparable\\\\scale} "
            "& \\makecell{States\\\\(dropped)} \\\\", "\\midrule"]
    for equation in ["violence", "sender"]:
        body.append(f"\\multicolumn{{9}}{{l}}{{\\textit{{{DIRECTION[equation]}}}}} \\\\")
        part = results[results.equation == equation]
        for model in ["Logit", "PPML", "PPML, winsorised"]:
            for controls in ["with_controls", "no_controls"]:
                rows = part[(part.model == model) & (part.control_set == controls)]
                if rows.empty:
                    continue
                r = rows.iloc[0]
                o = ols[(ols.specification == r.specification) & (ols.equation == equation) & (ols.control_set == controls)].iloc[0]
                if model == "Logit":
                    comparable = f"APE {num(r.average_partial_effect_sum)}"
                else:
                    change = 100 * (2.718281828459045 ** r.sum_cross_lags - 1)
                    comparable = f"{num(r.sum_cross_lags)} ({'+' if change >= 0 else '$-$'}{abs(change):.0f}\\%)"
                body.append(f"\\quad {model} & {CONTROL_LABEL[controls]} & {o.chi2:.2f}{stars(o.p_value)} & {num(o.sum_cross_lags)} & "
                            f"{r.chi2:.2f}{stars(r.p_value)} & {num(r.lag1)} & {num(r.lag2)} & {comparable} & "
                            f"{int(r.n_states)} ({int(r.states_dropped)}) \\\\")
        if equation == "violence":
            body.append("\\midrule")
    write("tab_nonlinear", table(
        "Robustness: logit and PPML versions of the reaction functions", "tab:nonlinear", "llccccccc", body,
        "Same samples, two lags, controls, state and year fixed effects and clustering as Table~\\ref{tab:granger}; "
        "fixed effects as dummies. Logit: incidence equations (conflict 0/1, new sanction 0/1); APE = sum of the two "
        "lag coefficients $\\times$ mean $\\hat p(1-\\hat p)$, an approximate average partial effect comparable to the "
        "linear-probability sum. PPML \\citep{santossilva2006}: levels equations with untransformed outcomes (deaths per "
        "100,000, also winsorised at the 99th percentile; number of new cases), right-hand side as in the levels VAR; "
        "sum in log points and implied proportional change. States whose outcome never varies carry no information "
        "with fixed effects and are dropped. $^{*}p<0.1$, $^{**}p<0.05$, $^{***}p<0.01$.",
        size="\\scriptsize\\setlength{\\tabcolsep}{3pt}"))


# ---------------------------------------------------------------------------
# 12. Raw deaths instead of log deaths in the levels VAR (robustness R10, script 09)
# ---------------------------------------------------------------------------
def raw_deaths() -> None:
    file = RESULTS / "robustness_raw_deaths.csv"
    if not file.exists():
        print("robustness_raw_deaths.csv not found (run 09_robustness.R): table skipped")
        return
    raw = pd.read_csv(file)
    raw = raw[raw.estimator == "OLS"]
    log = read("table1_granger")
    log = log[(log.estimator == "OLS") & (log.specification == "levels")]
    versions = ["raw", "winsorised_p99", "winsorised_p95"]
    caps = {v: raw[raw.version == v].cap.iloc[0] for v in versions}

    def fmt(chi2, p, total, digits):
        return f"\\makecell{{{chi2:.2f}{stars(p)}\\\\{{\\scriptsize [{num(total, digits)}]}}}}"

    body = [" & \\makecell{log(1+deaths)\\\\(Table~\\ref{tab:granger})} & \\makecell{Raw\\\\deaths} "
            f"& \\makecell{{Capped at p99\\\\({caps['winsorised_p99']:.1f})}} & \\makecell{{Capped at p95\\\\({caps['winsorised_p95']:.1f})}} \\\\",
            "\\midrule"]
    for equation in ["violence", "sender"]:
        body.append(f"\\multicolumn{{5}}{{l}}{{\\textit{{{DIRECTION[equation]}}}}} \\\\")
        for controls in ["with_controls", "no_controls"]:
            l = log[(log.equation == equation) & (log.control_set == controls)].iloc[0]
            cells = [fmt(l.chi2, l.p_value, l.sum_cross_lags, 3)]
            for v in versions:
                r = raw[(raw.version == v) & (raw.equation == equation) & (raw.control_set == controls)].iloc[0]
                cells.append(fmt(r.chi2, r.p_value, r.sum_cross_lags, 3 if equation == "violence" else 4))
            body.append(f"\\quad {CONTROL_LABEL[controls]} & " + " & ".join(cells) + " \\\\")
        if equation == "violence":
            body.append("\\midrule")
    roots = raw[raw.equation == "violence"].groupby("version").largest_root.min()
    means = raw[raw.equation == "violence"].groupby("version").mean_deaths.max()
    body += ["\\midrule",
             "Largest root (OLS) & " + f"{log.largest_root.min():.2f}--{log.largest_root.max():.2f} & "
             + " & ".join(f"{raw[(raw.version == v) & (raw.equation == 'violence')].largest_root.min():.2f}--"
                          f"{raw[(raw.version == v) & (raw.equation == 'violence')].largest_root.max():.2f}" for v in versions) + " \\\\",
             f"Mean of violence variable & {log[log.equation == 'violence'].mean_dependent.max():.2f} & " + " & ".join(f"{means[v]:.2f}" for v in versions) + " \\\\"]
    write("tab_raw_deaths", table(
        "Robustness: raw instead of log deaths in the levels VAR", "tab:rawdeaths", "lcccc", body,
        "FE-OLS levels VAR(2) as in Table~\\ref{tab:granger}, with deaths per 100,000 instead of "
        "$\\log(1+$deaths per 100,000$)$ as the violence variable (outcome and lags), as in the raw-count "
        "specification of \\citet{jaeger2008}. Caps at the 99th and 95th percentile of all state-years 1989--2019 "
        "(deaths per 100,000 in parentheses). Granger $\\chi^2(2)$; sum of the two cross-lag coefficients in brackets "
        "(sanctions$\\rightarrow$violence: deaths per 100,000 per new case; violence$\\rightarrow$sanctions: new cases "
        "per death per 100,000). Jackknife versions in \\texttt{robustness\\_raw\\_deaths.csv}. "
        "$^{*}p<0.1$, $^{**}p<0.05$, $^{***}p<0.01$.", size="\\footnotesize"))


# ---------------------------------------------------------------------------
# 13. Cumulative IRFs of the levels VAR with capped deaths (robustness R10, script 09)
# ---------------------------------------------------------------------------
def capped_irf() -> None:
    file = RESULTS / "robustness_capped_irf.csv"
    if not file.exists():
        print("robustness_capped_irf.csv not found (run 09_robustness.R): table skipped")
        return
    irf = pd.read_csv(file)
    irf = irf[(irf.horizon == 10) & (irf.shock != irf.response)]
    identifications = ["simple", "cholesky_sanction_first", "cholesky_violence_first"]
    body = [" & \\makecell{No same-year\\\\effect} & \\makecell{Cholesky,\\\\sanctions first} & \\makecell{Cholesky,\\\\violence first} \\\\",
            "\\midrule"]
    for shock, title in [("sanction", "One new sanction case $\\rightarrow$ deaths per 100,000"),
                         ("violence", "+1 death per 100,000 $\\rightarrow$ new sanction cases")]:
        body.append(f"\\multicolumn{{4}}{{l}}{{\\textit{{{title}}}}} \\\\")
        for controls in ["with_controls", "no_controls"]:
            cells = []
            for identification in identifications:
                r = irf[(irf.shock == shock) & (irf.control_set == controls) & (irf.identification == identification)].iloc[0]
                mark = "$^{\\ast}$" if (r.cumulative_lower > 0 or r.cumulative_upper < 0) else ""
                cells.append(f"\\makecell{{{num(r.cumulative)}{mark}\\\\{{\\scriptsize[{num(r.cumulative_lower)}, {num(r.cumulative_upper)}]}}}}")
            body.append(f"\\quad {CONTROL_LABEL[controls]} & " + " & ".join(cells) + " \\\\")
        if shock == "sanction":
            body.append("\\midrule")
    draws = int(irf.bootstrap_draws.iloc[0])
    write("tab_capped_irf", table(
        "Cumulative impulse responses after ten years, levels VAR with capped deaths", "tab:cappedirf", "lccc", body,
        f"Levels VAR(2) with deaths per 100,000 capped at the 99th percentile ({irf.cap.iloc[0]:.1f}) instead of log deaths; "
        "state and year fixed effects. Sum of the responses over years 0--10 to one new sanction case or to one additional "
        "death per 100,000; 95\\% country-cluster bootstrap intervals in brackets "
        f"({draws} draws); $^{{\\ast}}$ interval excludes zero. Identifications as in Table~\\ref{{tab:irf}}.",
        size="\\footnotesize"))


if __name__ == "__main__":
    descriptives()
    granger()
    coefficients()
    lag_grid()
    data_diagnostics()
    model_diagnostics()
    irf()
    gmm_diagnostics()
    gdelt()
    lpdid()
    nonlinear()
    raw_deaths()
    capped_irf()
