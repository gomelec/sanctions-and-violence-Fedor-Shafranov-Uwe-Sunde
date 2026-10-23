# =============================================================================
# 04_reaction_functions.R — the two reaction functions (= the two equations of
# the panel VAR) and the Granger tests.
# Panel version of Jaeger & Paserman (2008), Table 1 (empirics/ANALYSIS_PLAN.md, sections 3-4).
#
#   Violence equation: V_it = sum_k a_k V_i,t-k + sum_k b_k S_i,t-k + g'X_i,t-1 + state FE + year FE + e_it
#   Sender equation  : S_it = sum_k d_k S_i,t-k + sum_k c_k V_i,t-k + h'X_i,t-1 + state FE + year FE + u_it
#
#   Granger tests: H0: b_1 = ... = b_p = 0   (past sanctions do not predict violence)
#                  H0: c_1 = ... = c_p = 0   (past violence does not predict sanctions)
#
# Two specifications, as in Jaeger & Paserman:
#   incidence: S = new_sanction (0/1), V = conflict year (0/1)      -> linear probability models
#   levels   : S = n_new_cases (count), V = log(1 + deaths per 100,000)
# each with and without the lagged controls X.
#
# Two estimators:
#   OLS                  fixed-effects OLS, equation by equation (as Jaeger & Paserman)
#   half-panel jackknife bias-corrected version of the same regressions (Nickell bias;
#                        see functions.R and papers/README.md, entries 3 and 7)
# Standard errors are clustered by state throughout.
#
# Part 2 of the script: the lag grid (Jaeger & Paserman, Table 2): the same
# Granger tests for every combination of own lags and lags of the other
# variable from 1 to MAX_LAGS, on one common sample so that BIC is comparable.
#
# Input : empirics/results/data/analysis_panel.csv (from 01_prepare_sample.R)
# Output: empirics/results/tables/table1_reaction_functions.md   tables in Jaeger & Paserman layout
#         empirics/results/tables/table2_lag_grid.md             Granger tests across lag structures
#         empirics/results/tables/table2_lag_grid.csv
#         empirics/results/tables/table1_coefficients.csv        all slope coefficients
#         empirics/results/tables/table1_granger.csv             Granger tests, sample sizes, stability
#         empirics/results/models/table1_models.rds              fitted OLS models (for the IRFs later)
# =============================================================================

source(here::here("empirics", "scripts", "00_setup.R"))
source(here::here("empirics", "scripts", "functions.R"))

analysis <- read_csv(file.path(SAMPLE_DATA, "analysis_panel.csv"), show_col_types = FALSE)
N_LAGS <- VAR_LAGS                      # lag length p (set in 00_setup.R)

SPECIFICATIONS <- list(
  incidence = list(sanction = "new_sanction", violence = "viol_inc"),
  levels    = list(sanction = "n_new_cases",  violence = "viol_lev")
)
CONTROL_SETS <- list(with_controls = CONTROLS, no_controls = character(0))

VARIABLE_LABELS <- c(
  new_sanction = "New sanction (0/1)",
  n_new_cases  = "New sanction cases (count)",
  viol_inc     = paste0("Conflict, >= ", CONFLICT_MIN_DEATHS, " deaths (0/1)"),
  viol_lev     = "log(1 + deaths per 100,000)"
)

fitted_models     <- list()   # OLS models, kept for the impulse responses
coefficient_rows  <- list()   # one row per coefficient, equation, specification, estimator
granger_rows      <- list()   # one row per equation, specification, estimator


# =============================================================================
# 1. Estimate all equations
# =============================================================================
for (spec_name in names(SPECIFICATIONS)) {
  sanction <- SPECIFICATIONS[[spec_name]]$sanction
  violence <- SPECIFICATIONS[[spec_name]]$violence
  data_with_lags <- add_lags(analysis, c(sanction, violence), N_LAGS)

  for (control_set in names(CONTROL_SETS)) {
    controls <- CONTROL_SETS[[control_set]]

    # One common estimation sample for both equations, so together they form one VAR
    needed_columns <- c(sanction, violence, lag_names(sanction, N_LAGS),
                        lag_names(violence, N_LAGS), controls)
    estimation_sample <- data_with_lags %>%
      filter(in_window) %>%
      filter(if_all(all_of(needed_columns), ~ !is.na(.x)))

    # --- the two equations, OLS and bias-corrected ---------------------------------
    equations <- list(
      violence = list(outcome = violence, other = sanction),   # does violence respond to sanctions?
      sender   = list(outcome = sanction, other = violence)    # do senders respond to violence?
    )
    estimates <- list()
    for (equation_name in names(equations)) {
      outcome <- equations[[equation_name]]$outcome
      other   <- equations[[equation_name]]$other
      estimates[[equation_name]] <- list(
        OLS       = fit_reaction_function(estimation_sample, outcome, other, N_LAGS, controls),
        jackknife = half_panel_jackknife(estimation_sample, outcome, other, N_LAGS, controls)
      )
    }
    model_key <- paste(spec_name, control_set, sep = "_")
    fitted_models[[model_key]] <- list(violence = estimates$violence$OLS,
                                       sender   = estimates$sender$OLS)

    # --- collect coefficients, Granger tests and stability ---------------------------
    for (estimator in c("OLS", "jackknife")) {
      var_root <- largest_var_root(coef(estimates$violence[[estimator]]),
                                   coef(estimates$sender[[estimator]]),
                                   violence, sanction, N_LAGS)

      for (equation_name in names(equations)) {
        model   <- estimates[[equation_name]][[estimator]]
        outcome <- equations[[equation_name]]$outcome
        other   <- equations[[equation_name]]$other
        row_key <- paste(model_key, equation_name, estimator)

        coefficient_rows[[row_key]] <- coefficient_table(model) %>%
          mutate(specification = spec_name, control_set = control_set, estimator = estimator,
                 equation = equation_name, dependent_variable = outcome, .before = 1)

        granger_cross <- wald_test(model, lag_names(other, N_LAGS))     # the Granger test
        granger_own   <- wald_test(model, lag_names(outcome, N_LAGS))   # persistence (for reference)
        ols_model     <- estimates[[equation_name]]$OLS

        granger_rows[[row_key]] <- tibble(
          specification = spec_name, control_set = control_set, estimator = estimator,
          equation = equation_name, dependent_variable = outcome,
          hypothesis     = paste0("all lags of ", other, " = 0"),
          chi2           = granger_cross$chi2,
          df             = granger_cross$df,
          p_value        = granger_cross$p_value,
          sum_cross_lags = granger_cross$sum_coef,
          sum_cross_se   = granger_cross$sum_se,
          own_lags_chi2  = granger_own$chi2,
          own_lags_p     = granger_own$p_value,
          n_obs          = nobs(ols_model),
          n_states       = ols_model$n_states,
          first_year     = ols_model$year_range[1],
          last_year      = ols_model$year_range[2],
          mean_dependent = mean(estimation_sample[[outcome]]),
          largest_root   = var_root,
          jackknife_split_year = estimates[[equation_name]]$jackknife$split_year
        )
      }
    }
  }
}

coefficient_results <- bind_rows(coefficient_rows)
granger_results     <- bind_rows(granger_rows)
write_csv(coefficient_results, file.path(TABLES, "table1_coefficients.csv"))
write_csv(granger_results,     file.path(TABLES, "table1_granger.csv"))
saveRDS(fitted_models,         file.path(MODELS, "table1_models.rds"))


# =============================================================================
# 2. Tables in the layout of Jaeger & Paserman, Table 1 (markdown)
#    Columns: (1) sender eq., incidence  (2) sender eq., levels
#             (3) violence eq., incidence (4) violence eq., levels
# =============================================================================
TABLE_COLUMNS <- list(c("incidence", "sender"), c("levels", "sender"),
                      c("incidence", "violence"), c("levels", "violence"))

# Text of one cell: coefficient with stars and standard error below
coefficient_cell <- function(spec_name, equation_name, term, chosen_estimator, chosen_controls) {
  row <- coefficient_results %>%
    filter(specification == spec_name, equation == equation_name, term == !!term,
           estimator == chosen_estimator, control_set == chosen_controls)
  if (nrow(row) == 0) return("")
  sprintf("%.3f%s<br>(%.3f)", row$estimate, significance_stars(row$p_value), row$std_error)
}

# Text of one summary cell (Granger test, sample size, ...)
summary_cell <- function(spec_name, equation_name, what, chosen_estimator, chosen_controls) {
  row <- granger_results %>%
    filter(specification == spec_name, equation == equation_name,
           estimator == chosen_estimator, control_set == chosen_controls)
  switch(what,
         granger = sprintf("%.2f<br>(p = %.3f)", row$chi2, row$p_value),
         sum     = sprintf("%.3f (%.3f)", row$sum_cross_lags, row$sum_cross_se),
         sample  = sprintf("%d / %d", row$n_obs, row$n_states),
         years   = sprintf("%d–%d", row$first_year, row$last_year),
         mean    = sprintf("%.3f", row$mean_dependent),
         root    = sprintf("%.3f", row$largest_root))
}

# One table row across the four columns
table_row <- function(label, cell_function, ...) {
  cells <- sapply(TABLE_COLUMNS, function(column) cell_function(column[1], column[2], ...))
  paste0("| ", label, " | ", paste(cells, collapse = " | "), " |")
}

# Row for lag k of a variable type ("violence" or "sanction"): the variable name
# differs between the incidence and the levels columns
lag_row <- function(variable_type, k, chosen_estimator, chosen_controls) {
  cells <- sapply(TABLE_COLUMNS, function(column) {
    variable <- SPECIFICATIONS[[column[1]]][[variable_type]]
    coefficient_cell(column[1], column[2], paste0(variable, "_l", k), chosen_estimator, chosen_controls)
  })
  paste0("| t−", k, " | ", paste(cells, collapse = " | "), " |")
}

make_table <- function(chosen_estimator, chosen_controls) {
  with_controls <- chosen_controls == "with_controls"
  lines <- c(
    "| | (1) Sender eq. | (2) Sender eq. | (3) Violence eq. | (4) Violence eq. |",
    "|---|---|---|---|---|",
    paste0("| Dependent variable | ", VARIABLE_LABELS["new_sanction"], " | ", VARIABLE_LABELS["n_new_cases"],
           " | ", VARIABLE_LABELS["viol_inc"], " | ", VARIABLE_LABELS["viol_lev"], " |"),
    "| **Lagged violence** | | | | |",
    sapply(seq_len(N_LAGS), function(k) lag_row("violence", k, chosen_estimator, chosen_controls)),
    "| **Lagged new sanctions** | | | | |",
    sapply(seq_len(N_LAGS), function(k) lag_row("sanction", k, chosen_estimator, chosen_controls))
  )
  if (with_controls) {
    lines <- c(lines, "| **Controls (t−1)** | | | | |",
               sapply(CONTROLS, function(control)
                 table_row(control, coefficient_cell, term = control,
                           chosen_estimator = chosen_estimator, chosen_controls = chosen_controls)))
  }
  c(lines,
    table_row(paste0("**Granger χ²(", N_LAGS, ") for the other side's lags**"), summary_cell,
              what = "granger", chosen_estimator = chosen_estimator, chosen_controls = chosen_controls),
    table_row("Sum of the other side's lag coefficients (SE)", summary_cell,
              what = "sum", chosen_estimator = chosen_estimator, chosen_controls = chosen_controls),
    table_row("Observations / states", summary_cell,
              what = "sample", chosen_estimator = chosen_estimator, chosen_controls = chosen_controls),
    table_row("Years", summary_cell,
              what = "years", chosen_estimator = chosen_estimator, chosen_controls = chosen_controls),
    table_row("Mean of dependent variable", summary_cell,
              what = "mean", chosen_estimator = chosen_estimator, chosen_controls = chosen_controls),
    table_row("Largest root of the VAR (stable if < 1)", summary_cell,
              what = "root", chosen_estimator = chosen_estimator, chosen_controls = chosen_controls),
    "| State FE, year FE | yes | yes | yes | yes |",
    "")
}

split_year <- granger_results$jackknife_split_year[1]
notes <- paste0(
  "*Notes:* OLS = fixed-effects OLS, equation by equation. Jackknife = half-panel jackknife ",
  "(2 × full-sample estimate − average of the two half-sample estimates; halves split after ", split_year,
  ") to remove the Nickell bias; it uses the full-sample clustered covariance. Standard errors clustered by ",
  "state in parentheses; * p<0.1, ** p<0.05, *** p<0.01. Sample ", min(SAMPLE_YEARS), "–", max(SAMPLE_YEARS),
  "; violence data start in 1989, so with ", N_LAGS, " lags the first usable year is ",
  min(SAMPLE_YEARS) + N_LAGS, ". Granger χ²: Wald test that all lags of the other variable are zero ",
  "(sender equation: lags of violence; violence equation: lags of new sanctions). Largest root: modulus of ",
  "the largest eigenvalue of the companion matrix of the VAR formed by the two equations.")

markdown <- c(
  "# Table 1 — Reaction functions (panel version of Jaeger & Paserman 2008, Table 1)", "",
  paste0("Generated by `empirics/scripts/04_reaction_functions.R` on ", format(Sys.time(), "%Y-%m-%d %H:%M"), "."), "",
  "## A. OLS, with lagged controls", "",                         make_table("OLS", "with_controls"),
  "## B. OLS, without controls (Jaeger & Paserman, footnote 4)", "", make_table("OLS", "no_controls"),
  "## C. Half-panel jackknife (bias-corrected), with lagged controls", "", make_table("jackknife", "with_controls"),
  "## D. Half-panel jackknife (bias-corrected), without controls", "", make_table("jackknife", "no_controls"),
  notes
)
writeLines(markdown, file.path(TABLES, "table1_reaction_functions.md"))


# =============================================================================
# 3. Lag grid (Jaeger & Paserman, Table 2)
#    Every combination of own lags (1..MAX_LAGS) and lags of the other variable
#    (1..MAX_LAGS). All combinations use the same sample -- the state-years with
#    MAX_LAGS lags of both variables available -- so that their BIC values can be
#    compared; the first usable year is therefore later than in Table 1.
# =============================================================================
lag_grid <- expand.grid(own_lags = seq_len(MAX_LAGS), other_lags = seq_len(MAX_LAGS))
grid_rows <- list()

for (spec_name in names(SPECIFICATIONS)) {
  sanction <- SPECIFICATIONS[[spec_name]]$sanction
  violence <- SPECIFICATIONS[[spec_name]]$violence
  data_with_lags <- add_lags(analysis, c(sanction, violence), MAX_LAGS)

  for (control_set in names(CONTROL_SETS)) {
    controls <- CONTROL_SETS[[control_set]]
    needed_columns <- c(sanction, violence, lag_names(sanction, MAX_LAGS),
                        lag_names(violence, MAX_LAGS), controls)
    common_sample <- data_with_lags %>%
      filter(in_window) %>%
      filter(if_all(all_of(needed_columns), ~ !is.na(.x)))

    equations <- list(violence = list(outcome = violence, other = sanction),
                      sender   = list(outcome = sanction, other = violence))

    for (row in seq_len(nrow(lag_grid))) {
      own_lags   <- lag_grid$own_lags[row]
      other_lags <- lag_grid$other_lags[row]

      for (equation_name in names(equations)) {
        outcome <- equations[[equation_name]]$outcome
        other   <- equations[[equation_name]]$other
        ols_model <- fit_reaction_function(common_sample, outcome, other, own_lags, controls,
                                           n_lags_other = other_lags)
        jackknife <- half_panel_jackknife(common_sample, outcome, other, own_lags, controls,
                                          n_lags_other = other_lags)

        for (estimator in c("OLS", "jackknife")) {
          model   <- if (estimator == "OLS") ols_model else jackknife
          granger <- wald_test(model, lag_names(other, other_lags))
          grid_rows[[length(grid_rows) + 1]] <- tibble(
            specification = spec_name, control_set = control_set, estimator = estimator,
            equation = equation_name, own_lags = own_lags, other_lags = other_lags,
            chi2 = granger$chi2, df = granger$df, p_value = granger$p_value,
            sum_cross_lags = granger$sum_coef, sum_cross_se = granger$sum_se,
            bic = BIC(ols_model),                        # OLS likelihood; same sample for all cells
            n_obs = nobs(ols_model), first_year = min(common_sample$yr)
          )
        }
      }
    }
  }
}

grid_results <- bind_rows(grid_rows) %>%
  group_by(specification, control_set, estimator, equation) %>%
  mutate(lowest_bic = bic == min(bic)) %>%                  # BIC-preferred lag structure per equation
  ungroup()
write_csv(grid_results, file.path(TABLES, "table2_lag_grid.csv"))

# --- markdown: one panel per estimator and control set ------------------------------
grid_cell <- function(spec_name, equation_name, own, other, chosen_estimator, chosen_controls) {
  row <- grid_results %>%
    filter(specification == spec_name, equation == equation_name, own_lags == own,
           other_lags == other, estimator == chosen_estimator, control_set == chosen_controls)
  sprintf("%.2f%s (p = %.3f)%s", row$chi2, significance_stars(row$p_value), row$p_value,
          ifelse(row$lowest_bic, " †", ""))
}

grid_table <- function(chosen_estimator, chosen_controls) {
  lines <- c("| Lags (own, other) | (1) Sender eq., incidence | (2) Sender eq., levels | (3) Violence eq., incidence | (4) Violence eq., levels |",
             "|---|---|---|---|---|")
  for (row in seq_len(nrow(lag_grid))) {
    own <- lag_grid$own_lags[row]; other <- lag_grid$other_lags[row]
    cells <- sapply(TABLE_COLUMNS, function(column)
      grid_cell(column[1], column[2], own, other, chosen_estimator, chosen_controls))
    lines <- c(lines, paste0("| (", own, ", ", other, ") | ", paste(cells, collapse = " | "), " |"))
  }
  c(lines, "")
}

grid_first_year <- min(grid_results$first_year)
grid_markdown <- c(
  "# Table 2 — Granger tests for different lag structures (panel version of Jaeger & Paserman 2008, Table 2)", "",
  paste0("Generated by `empirics/scripts/04_reaction_functions.R` on ", format(Sys.time(), "%Y-%m-%d %H:%M"), "."), "",
  "Each cell: χ² statistic for the joint significance of the other variable's lags (p-value). ",
  "(own, other) = number of lags of the dependent variable and of the other variable. † = lowest BIC in that column.", "",
  "## A. OLS, with lagged controls", "",          grid_table("OLS", "with_controls"),
  "## B. OLS, without controls", "",              grid_table("OLS", "no_controls"),
  "## C. Half-panel jackknife, with lagged controls", "", grid_table("jackknife", "with_controls"),
  "## D. Half-panel jackknife, without controls", "",     grid_table("jackknife", "no_controls"),
  paste0("*Notes:* All lag structures are estimated on the same sample (state-years with ", MAX_LAGS,
         " lags of both variables; first year ", grid_first_year, "), so BIC values are comparable within a column. ",
         "State and year fixed effects; standard errors clustered by state; * p<0.1, ** p<0.05, *** p<0.01. ",
         "Sender equation: test of the lags of violence; violence equation: test of the lags of new sanctions.")
)
writeLines(grid_markdown, file.path(TABLES, "table2_lag_grid.md"))


# =============================================================================
# 4. Log: the Granger tests side by side
# =============================================================================
cat("\nGranger tests (Wald, clustered by state):\n")
granger_results %>%
  transmute(specification, control_set, estimator, equation, hypothesis,
            chi2 = round(chi2, 2), p_value = round(p_value, 4),
            sum_cross_lags = round(sum_cross_lags, 4), n_obs, n_states,
            largest_root = round(largest_root, 3)) %>%
  as.data.frame() %>%
  print(row.names = FALSE)
cat("\nLag grid (OLS, no controls): Granger p-values\n")
grid_results %>%
  filter(estimator == "OLS", control_set == "no_controls") %>%
  transmute(specification, equation, lags = paste0("(", own_lags, ",", other_lags, ")"),
            p_value = round(p_value, 3)) %>%
  pivot_wider(names_from = lags, values_from = p_value) %>%
  as.data.frame() %>% print(row.names = FALSE)
cat("\nWrote", file.path(TABLES, "table1_reaction_functions.md"), "and table2_lag_grid.md\n")
