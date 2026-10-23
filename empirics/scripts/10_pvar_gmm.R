# =============================================================================
# 10_pvar_gmm.R — GMM panel VAR (robustness check R8 in empirics/ANALYSIS_PLAN.md)
#
# Same bivariate panel VAR as 04_reaction_functions.R, but estimated by GMM
# instead of fixed-effects OLS (Holtz-Eakin, Newey & Rosen 1988; Love & Zicchino
# 2006; Abrigo & Love 2016), with the R package panelvar (pvargmm).
#
# Why GMM: OLS with state fixed effects and lagged dependent variables has the
# Nickell bias. GMM removes the fixed effects with forward orthogonal deviations
# (FOD: each value minus the mean of all FUTURE values of that state) and uses
# older lags of the variables, in levels, as instruments.
#
# GMM is only valid if (papers/README.md, entry 9):
#   - the errors are not serially correlated (older lags are valid instruments),
#   - the instruments are relevant (series not close to a unit root),
#   - the number of instruments stays well below the number of states
#     (otherwise GMM drifts back towards OLS and the Hansen test loses power):
#     hence collapsed instruments and only lags 2-5 as instruments.
#   - more moment conditions than parameters: with lags 2-3 only, each equation
#     has 4 instruments for 4 lag coefficients (exactly identified, Hansen
#     chi2(0) - nothing to test); lags 2-5 give 8 instruments per equation,
#     so the Hansen test has 4 degrees of freedom per equation.
# Diagnostics reported: Hansen J test (should NOT reject; a p-value near 1 is
# also a warning sign), number of moment conditions vs number of states,
# Andrews-Lu model selection criteria for the lag length, VAR stability.
#
# Year effects: pvargmm has no year fixed effects, so every variable is
# demeaned by year first (the cross-state mean of each year is subtracted),
# which removes common shocks in the same way as year dummies.
#
# Controls: in the "with_controls" version the lagged controls enter as
# exogenous variables (a simplification: they are predetermined, not strictly
# exogenous). The main GMM version is without controls.
#
# Input : empirics/results/data/analysis_panel.csv (from 01_prepare_sample.R)
#         empirics/results/tables/table1_granger.csv (from 04, for the comparison)
# Output: empirics/results/tables/gmm_pvar.md                 comparison OLS / jackknife / GMM
#         empirics/results/tables/gmm_coefficients.csv
#         empirics/results/tables/gmm_granger.csv
#         empirics/results/tables/gmm_lag_selection.csv       Andrews-Lu MMSC for 1-3 lags
#         empirics/results/models/gmm_models.rds
# =============================================================================

source(here::here("empirics", "scripts", "00_setup.R"))
source(here::here("empirics", "scripts", "functions.R"))
suppressPackageStartupMessages(library(panelvar))

analysis <- read_csv(file.path(SAMPLE_DATA, "analysis_panel.csv"), show_col_types = FALSE)
N_LAGS <- VAR_LAGS

SPECIFICATIONS <- list(
  incidence = list(sanction = "new_sanction", violence = "viol_inc"),
  levels    = list(sanction = "n_new_cases",  violence = "viol_lev")
)
CONTROL_SETS <- list(no_controls = character(0), with_controls = CONTROLS)

# GMM settings (Abrigo & Love 2016; Roodman 2009 on instrument proliferation)
GMM_SETTINGS <- list(
  transformation           = "fod",       # forward orthogonal deviations (fewer lost obs. in unbalanced panels)
  steps                    = "twostep",   # efficient two-step GMM
  system_instruments       = FALSE,       # difference GMM only (no level equation)
  collapse                 = TRUE,        # one instrument per lag, not one per lag and year
  min_instr_dependent_vars = 2L,          # instruments start at lag 2 ...
  max_instr_dependent_vars = 5L           # ... and stop at lag 5 (overidentified, see header)
)
LAGS_FOR_SELECTION <- 1:3                 # lag lengths compared with the Andrews-Lu criteria


# =============================================================================
# Helper functions (specific to panelvar output)
# =============================================================================

# Subtract the cross-state mean of each year from every variable (= year effects)
demean_by_year <- function(data, variables) {
  data %>%
    group_by(yr) %>%
    mutate(across(all_of(variables), ~ .x - mean(.x, na.rm = TRUE))) %>%
    ungroup()
}

# Fit one GMM panel VAR; returns the model or an error message instead of stopping
fit_gmm <- function(data, dependent_variables, n_lags, exogenous_variables = character(0)) {
  arguments <- c(list(dependent_vars   = dependent_variables,
                      lags             = n_lags,
                      data             = as.data.frame(data),     # panelvar needs a plain data.frame
                      panel_identifier = c("gwcode", "yr"),
                      progressbar      = FALSE),
                 GMM_SETTINGS)
  if (length(exogenous_variables) > 0) arguments$exog_vars <- exogenous_variables
  tryCatch(do.call(pvargmm, arguments),
           error = function(e) structure(list(message = conditionMessage(e)), class = "gmm_failed"))
}

# Coefficient and standard-error matrices of the two-step estimates.
# Rows = equations ("fod_viol_inc", ...), columns = regressors ("fod_lag1_viol_inc", ...).
# Our names: equation "viol_inc"; regressor "viol_inc_l1" (lags) or "ctrl_stock" (controls).
gmm_estimates <- function(model) {
  coefficients <- as.matrix(model$second_step)
  std_errors   <- matrix(as.numeric(as.matrix(model$standard_error_second_step)),
                         nrow = nrow(coefficients), dimnames = dimnames(coefficients))
  clean_names <- function(x) {
    x <- sub("^fod_", "", x)
    sub("^lag([0-9]+)_(.*)$", "\\2_l\\1", x)          # lag1_viol_inc -> viol_inc_l1
  }
  dimnames(coefficients) <- dimnames(std_errors) <- list(clean_names(rownames(coefficients)),
                                                          clean_names(colnames(coefficients)))
  list(coefficients = coefficients, std_errors = std_errors)
}

# Covariance of the coefficients of one equation. panelvar stores the
# coefficients equation by equation in column-major order of the coefficient
# matrix; vcov() is checked against the reported standard errors before use.
# If the full covariance is not available, the diagonal is used and the Granger
# test is flagged as approximate (covariances between lags ignored).
equation_covariance <- function(model, estimates, equation) {
  n_equations  <- nrow(estimates$coefficients)
  n_regressors <- ncol(estimates$coefficients)
  row_index    <- match(equation, rownames(estimates$coefficients))
  positions    <- (seq_len(n_regressors) - 1) * n_equations + row_index

  full_covariance <- tryCatch(as.matrix(vcov(model)), error = function(e) NULL)
  usable <- !is.null(full_covariance) &&
    nrow(full_covariance) == n_equations * n_regressors &&
    isTRUE(all.equal(sqrt(diag(full_covariance))[positions],
                     unname(estimates$std_errors[equation, ]), tolerance = 1e-6))
  covariance <- if (usable) full_covariance[positions, positions] else diag(estimates$std_errors[equation, ]^2)
  dimnames(covariance) <- list(colnames(estimates$coefficients), colnames(estimates$coefficients))
  list(covariance = covariance, exact = usable)
}

# Hansen J test of overidentifying restrictions (statistic, df, p-value)
hansen_test <- function(model) {
  result <- tryCatch(hansen_j_test(model), error = function(e) NULL)
  if (is.null(result)) return(tibble(hansen_j = NA_real_, hansen_df = NA_real_, hansen_p = NA_real_))
  tibble(hansen_j  = as.numeric(unlist(result$statistic))[1],
         hansen_df = as.numeric(unlist(result$parameter))[1],
         hansen_p  = as.numeric(unlist(result$p.value))[1])
}


# =============================================================================
# 1. Estimate the GMM panel VARs
# =============================================================================
gmm_models   <- list()
coefficient_rows <- list()
granger_rows <- list()
selection_rows <- list()

for (spec_name in names(SPECIFICATIONS)) {
  sanction <- SPECIFICATIONS[[spec_name]]$sanction
  violence <- SPECIFICATIONS[[spec_name]]$violence

  for (control_set in names(CONTROL_SETS)) {
    controls <- CONTROL_SETS[[control_set]]

    # keep the variables of this specification, remove year means
    gmm_data <- analysis %>%
      select(gwcode, yr, all_of(c(violence, sanction, controls))) %>%
      demean_by_year(c(violence, sanction, controls))

    model_key <- paste(spec_name, control_set, sep = "_")
    cat("\n=====", model_key, "=====\n")
    model <- fit_gmm(gmm_data, c(violence, sanction), N_LAGS, controls)
    gmm_models[[model_key]] <- model

    if (inherits(model, "gmm_failed")) {
      cat("GMM failed:", model$message, "\n")
      granger_rows[[model_key]] <- tibble(specification = spec_name, control_set = control_set,
                                          estimator = "GMM", note = paste("failed:", model$message))
      next
    }
    print(summary(model))

    estimates <- gmm_estimates(model)
    hansen    <- hansen_test(model)
    n_moment_conditions <- nrow(model$weighting_matrix_second_step)
    var_root  <- largest_var_root(estimates$coefficients[violence, ], estimates$coefficients[sanction, ],
                                  violence, sanction, N_LAGS)

    equations <- list(violence = list(outcome = violence, other = sanction),
                      sender   = list(outcome = sanction, other = violence))
    for (equation_name in names(equations)) {
      outcome <- equations[[equation_name]]$outcome
      other   <- equations[[equation_name]]$other

      # coefficients of this equation
      coefficient_rows[[paste(model_key, equation_name)]] <- tibble(
        specification = spec_name, control_set = control_set, estimator = "GMM",
        equation = equation_name, dependent_variable = outcome,
        term      = colnames(estimates$coefficients),
        estimate  = estimates$coefficients[outcome, ],
        std_error = estimates$std_errors[outcome, ]
      ) %>% mutate(p_value = 2 * pnorm(-abs(estimate / std_error)))

      # Granger test: Wald test that all lags of the other variable are zero
      covariance  <- equation_covariance(model, estimates, outcome)
      cross_terms <- lag_names(other, N_LAGS)
      granger_input <- list(coefficients = estimates$coefficients[outcome, ],
                            vcov_clustered = covariance$covariance)
      class(granger_input) <- "jackknife"            # reuse coef() method from functions.R
      granger <- wald_test(granger_input, cross_terms)

      granger_rows[[paste(model_key, equation_name)]] <- tibble(
        specification = spec_name, control_set = control_set, estimator = "GMM",
        equation = equation_name, dependent_variable = outcome,
        hypothesis = paste0("all lags of ", other, " = 0"),
        chi2 = granger$chi2, df = granger$df, p_value = granger$p_value,
        sum_cross_lags = granger$sum_coef, sum_cross_se = granger$sum_se,
        wald_uses_full_covariance = covariance$exact,
        n_obs = model$nof_observations, n_states = model$nof_groups,
        n_moment_conditions = n_moment_conditions,
        too_many_instruments = n_moment_conditions >= model$nof_groups,
        largest_root = var_root
      ) %>% bind_cols(hansen)
    }
  }

  # --- lag-length selection (Andrews & Lu 2001), without controls ----------------------
  for (n_lags in LAGS_FOR_SELECTION) {
    selection_data <- analysis %>%
      select(gwcode, yr, all_of(c(violence, sanction))) %>%
      demean_by_year(c(violence, sanction))
    selection_model <- fit_gmm(selection_data, c(violence, sanction), n_lags)
    criteria <- if (inherits(selection_model, "gmm_failed")) NULL else
      tryCatch(Andrews_Lu_MMSC(selection_model), error = function(e) NULL)
    selection_rows[[paste(spec_name, n_lags)]] <- tibble(
      specification = spec_name, n_lags = n_lags,
      mmsc_bic  = if (is.null(criteria)) NA_real_ else criteria$MMSC_BIC,
      mmsc_aic  = if (is.null(criteria)) NA_real_ else criteria$MMSC_AIC,
      mmsc_hqic = if (is.null(criteria)) NA_real_ else criteria$MMSC_HQIC
    )
  }
}

if (length(coefficient_rows) == 0) stop("All GMM estimations failed - see the messages above.")

gmm_coefficients <- bind_rows(coefficient_rows)
gmm_granger      <- bind_rows(granger_rows)
lag_selection    <- bind_rows(selection_rows) %>%
  group_by(specification) %>%
  mutate(chosen_by_bic = mmsc_bic == min(mmsc_bic, na.rm = TRUE)) %>%
  ungroup()

write_csv(gmm_coefficients, file.path(TABLES, "gmm_coefficients.csv"))
write_csv(gmm_granger,      file.path(TABLES, "gmm_granger.csv"))
write_csv(lag_selection,    file.path(TABLES, "gmm_lag_selection.csv"))
saveRDS(gmm_models,         file.path(MODELS, "gmm_models.rds"))


# =============================================================================
# 2. Comparison table: Granger tests by estimator (markdown)
# =============================================================================
ols_and_jackknife <- read_csv(file.path(TABLES, "table1_granger.csv"), show_col_types = FALSE)

comparison <- bind_rows(
  ols_and_jackknife %>% select(specification, control_set, estimator, equation, chi2, p_value, sum_cross_lags),
  gmm_granger %>% filter(!is.na(chi2)) %>%
    select(specification, control_set, estimator, equation, chi2, p_value, sum_cross_lags)
) %>%
  mutate(cell = sprintf("%.2f (p = %.3f), sum %.3f", chi2, p_value, sum_cross_lags),
         direction = ifelse(equation == "violence", "Sanctions → violence", "Violence → sanctions")) %>%
  select(direction, specification, control_set, estimator, cell) %>%
  pivot_wider(names_from = estimator, values_from = cell) %>%
  arrange(direction, specification, control_set)

diagnostics <- gmm_granger %>%
  filter(equation == "violence" | is.na(equation)) %>%          # one row per model
  transmute(specification, control_set,
            states = n_states, observations = n_obs, moment_conditions = n_moment_conditions,
            hansen = ifelse(is.na(hansen_j), "n/a", sprintf("%.2f (df %s, p = %.3f)", hansen_j, hansen_df, hansen_p)),
            largest_root = round(largest_root, 3),
            full_covariance_in_wald = wald_uses_full_covariance)

to_markdown <- function(table) {
  header <- paste0("| ", paste(names(table), collapse = " | "), " |")
  divider <- paste0("|", paste(rep("---", ncol(table)), collapse = "|"), "|")
  rows <- apply(table, 1, function(row) paste0("| ", paste(ifelse(is.na(row), "", row), collapse = " | "), " |"))
  c(header, divider, rows, "")
}

markdown <- c(
  "# GMM panel VAR — robustness check (plan R8)", "",
  paste0("Generated by `empirics/scripts/10_pvar_gmm.R` on ", format(Sys.time(), "%Y-%m-%d %H:%M"), "."), "",
  paste0("## A. Granger tests by estimator: χ²(", N_LAGS, ") (p-value), sum of the other side's lag coefficients"), "",
  to_markdown(comparison),
  "## B. GMM diagnostics", "",
  to_markdown(diagnostics),
  "## C. Lag length: Andrews–Lu model selection criteria (GMM, no controls; lowest is preferred)", "",
  to_markdown(lag_selection %>% mutate(across(starts_with("mmsc"), ~ round(.x, 2)))),
  paste0("*Notes:* GMM = two-step difference GMM with forward orthogonal deviations, collapsed instruments ",
         "(lags ", GMM_SETTINGS$min_instr_dependent_vars, "–", GMM_SETTINGS$max_instr_dependent_vars,
         " of the dependent variables), all variables demeaned by year (year effects). ",
         "Hansen J should not reject; the number of moment conditions should stay well below the number of states. ",
         "If 'full_covariance_in_wald' is FALSE, the GMM Granger test ignores the covariance between the lag ",
         "coefficients and is approximate.")
)
writeLines(markdown, file.path(TABLES, "gmm_pvar.md"))

cat("\nGranger tests by estimator:\n"); print(as.data.frame(comparison), row.names = FALSE)
cat("\nGMM diagnostics:\n");             print(as.data.frame(diagnostics), row.names = FALSE)
cat("\nLag selection:\n");               print(as.data.frame(lag_selection), row.names = FALSE)
cat("\nWrote", file.path(TABLES, "gmm_pvar.md"), "\n")
