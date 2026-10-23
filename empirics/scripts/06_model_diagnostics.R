# =============================================================================
# 06_model_diagnostics.R — checks on the ESTIMATED reaction functions
# (empirics/ANALYSIS_PLAN.md, sections 4 and 6)
#
#   M1  Residual serial correlation: are the lags enough?
#       If the residuals are still autocorrelated, the VAR misses dynamics, the
#       Granger tests are distorted and GMM instruments (lagged levels) are invalid.
#       Test (Wooldridge 2010, ch. 10.5.4): regress the fixed-effects residual on its
#       own lag. Without serial correlation in the true errors, the coefficient of
#       DEMEANED residuals is -1/(T-1), not 0, so that is the null hypothesis.
#       Done for lag 1 and lag 2 of the residual. Standard errors clustered by state.
#   M2  Cross-sectional dependence of the residuals: Pesaran (2004, 2015) CD test.
#       Common shocks beyond the year effects (sanction waves, global conflict
#       trends) would make residuals correlated across states; clustering by state
#       would then understate the uncertainty.
#   M3  Stability of every estimated VAR (largest root of the companion matrix):
#       OLS, jackknife (from 04) and GMM (from 10, if it has been run).
#
# Input : empirics/results/models/table1_models.rds   (OLS models from 04)
#         empirics/results/tables/table1_granger.csv  (stability, from 04)
#         empirics/results/tables/gmm_granger.csv     (stability, from 10; optional)
# Output: empirics/results/tables/model_diagnostics.md
#         empirics/results/tables/diag_residual_autocorrelation.csv
#         empirics/results/tables/diag_cross_section_dependence.csv
#         empirics/results/tables/diag_stability.csv
# =============================================================================

source(here::here("empirics", "scripts", "00_setup.R"))
source(here::here("empirics", "scripts", "functions.R"))

fitted_models <- readRDS(file.path(MODELS, "table1_models.rds"))
MIN_OVERLAP   <- 10          # CD test: minimum number of common years for a pair of states


# =============================================================================
# Helper functions
# =============================================================================

# Residuals of a fitted reaction function with their state and year
residual_panel <- function(model) {
  frame <- model$model                                   # data used in the regression
  tibble(gwcode   = as.integer(as.character(frame[["factor(gwcode)"]])),
         yr       = as.integer(as.character(frame[["factor(yr)"]])),
         outcome  = frame[[1]],                           # the dependent variable
         residual = unname(residuals(model)))
}

# M1: autocorrelation of the FE residuals at lag k, tested against -1/(T-1)
residual_autocorrelation <- function(residuals_by_year, k) {
  residuals_by_year$residual_lag <- lag_by_year(residuals_by_year, "residual", k)
  pairs <- residuals_by_year %>% filter(!is.na(residual_lag))
  fit <- lm(residual ~ residual_lag, data = pairs)
  covariance <- sandwich::vcovCL(fit, cluster = pairs$gwcode, type = "HC1")
  rho <- coef(fit)[["residual_lag"]]
  se  <- sqrt(covariance["residual_lag", "residual_lag"])
  average_T <- nrow(residuals_by_year) / n_distinct(residuals_by_year$gwcode)
  expected_without_autocorrelation <- -1 / (average_T - 1)
  z <- (rho - expected_without_autocorrelation) / se
  tibble(lag = k, rho = rho, se = se, expected_under_h0 = expected_without_autocorrelation,
         z = z, p_value = 2 * pnorm(-abs(z)))
}

# M2: Pesaran CD test for an unbalanced panel.
# only_varying_outcome = TRUE drops states whose dependent variable never changes
# (e.g. never in conflict): their residual is just minus the year effects, identical
# for all of them, which creates cross-state correlation mechanically.
#   CD = sqrt(1 / number of pairs) * sum over pairs of sqrt(T_ij) * rho_ij  ~ N(0, 1)
# rho_ij = correlation of the residuals of states i and j over their common years.
pesaran_cd <- function(residuals_by_year, only_varying_outcome = FALSE) {
  if (only_varying_outcome) {
    residuals_by_year <- residuals_by_year %>%
      group_by(gwcode) %>% filter(n_distinct(outcome) > 1) %>% ungroup()
  }
  wide <- residuals_by_year %>%
    select(gwcode, yr, residual) %>%
    pivot_wider(names_from = gwcode, values_from = residual) %>%
    arrange(yr) %>% select(-yr) %>% as.matrix()
  wide <- wide[, apply(wide, 2, function(x) sum(!is.na(x)) >= MIN_OVERLAP & sd(x, na.rm = TRUE) > 1e-10),
               drop = FALSE]
  observed <- !is.na(wide)
  overlap  <- crossprod(observed * 1)                               # T_ij: common years of each pair
  correlations <- suppressWarnings(cor(wide, use = "pairwise.complete.obs"))
  use_pair <- upper.tri(overlap) & overlap >= MIN_OVERLAP & !is.na(correlations)
  rho <- correlations[use_pair]
  cd  <- sum(sqrt(overlap[use_pair]) * rho) / sqrt(sum(use_pair))
  tibble(states = ncol(wide), pairs = sum(use_pair),
         mean_correlation = mean(rho), mean_abs_correlation = mean(abs(rho)),
         cd = cd, p_value = 2 * pnorm(-abs(cd)))
}


# =============================================================================
# M1 + M2 for every equation of Table 1
# =============================================================================
autocorrelation_rows <- list(); cd_rows <- list()
for (model_key in names(fitted_models)) {
  for (equation_name in c("violence", "sender")) {
    fitted_model <- fitted_models[[model_key]][[equation_name]]
    residuals_by_year <- residual_panel(fitted_model)
    labels <- tibble(model = model_key, equation = equation_name,
                     dependent_variable = names(fitted_model$model)[1])
    for (k in 1:2) {
      autocorrelation_rows[[paste(model_key, equation_name, k)]] <-
        bind_cols(labels, residual_autocorrelation(residuals_by_year, k))
    }
    for (only_varying in c(FALSE, TRUE)) {
      cd_rows[[paste(model_key, equation_name, only_varying)]] <- bind_cols(
        labels, tibble(states_used = ifelse(only_varying, "outcome varies", "all")),
        pesaran_cd(residuals_by_year, only_varying_outcome = only_varying))
    }
  }
}
autocorrelation <- bind_rows(autocorrelation_rows)
cross_dependence <- bind_rows(cd_rows)
write_csv(autocorrelation,  file.path(TABLES, "diag_residual_autocorrelation.csv"))
write_csv(cross_dependence, file.path(TABLES, "diag_cross_section_dependence.csv"))


# =============================================================================
# M3 Stability across estimators
# =============================================================================
stability <- read_csv(file.path(TABLES, "table1_granger.csv"), show_col_types = FALSE) %>%
  filter(equation == "violence") %>%                       # one row per VAR (both equations share the root)
  select(specification, control_set, estimator, largest_root)
gmm_file <- file.path(TABLES, "gmm_granger.csv")
if (file.exists(gmm_file)) {
  stability <- bind_rows(stability,
                         read_csv(gmm_file, show_col_types = FALSE) %>%
                           filter(equation == "violence") %>%
                           select(specification, control_set, estimator, largest_root))
}
stability <- stability %>% mutate(stable = largest_root < 1) %>% arrange(specification, control_set, estimator)
write_csv(stability, file.path(TABLES, "diag_stability.csv"))


# =============================================================================
# Report (markdown)
# =============================================================================
to_markdown <- function(table, digits = 3) {
  table <- table %>% mutate(across(where(is.numeric), ~ round(.x, digits)))
  c(paste0("| ", paste(names(table), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(table)), collapse = "|"), "|"),
    apply(table, 1, function(row) paste0("| ", paste(ifelse(is.na(row), "", trimws(row)), collapse = " | "), " |")),
    "")
}

markdown <- c(
  "# Model diagnostics (after estimation)", "",
  paste0("Generated by `empirics/scripts/06_model_diagnostics.R` on ", format(Sys.time(), "%Y-%m-%d %H:%M"),
         ". Models: Table 1 (OLS, ", VAR_LAGS, " lags), from `04_reaction_functions.R`."), "",
  "## M1. Residual serial correlation (are the lags enough?)", "",
  "Coefficient of the fixed-effects residual on its own lag k. Without serial correlation in the true errors it ",
  "equals −1/(T−1) (not 0), because the residuals are demeaned within each state; a small p-value means remaining ",
  "autocorrelation, i.e. the VAR misses dynamics.", "",
  to_markdown(autocorrelation %>% select(model, equation, lag, rho, se, expected_under_h0, z, p_value)),
  "## M2. Cross-sectional dependence of the residuals (Pesaran CD test)", "",
  paste0("H0: residuals are uncorrelated across states. Pairs of states with at least ", MIN_OVERLAP,
         " common years. With year effects in the model, the average correlation is mechanically close to zero, so ",
         "the test picks up common shocks that hit states with different strength. A rejection argues for ",
         "Driscoll–Kraay standard errors or the country bootstrap as a check."), "",
  "\"outcome varies\" drops states whose dependent variable is constant (e.g. never in conflict): for them the ",
  "residual is minus the year effects, identical across these states, which creates correlation mechanically.", "",
  to_markdown(cross_dependence %>% select(model, equation, states_used, states, pairs, mean_correlation,
                                          mean_abs_correlation, cd, p_value)),
  "## M3. Stability of every estimated VAR", "",
  "Largest modulus of the companion-matrix eigenvalues; below 1 = stable (shocks die out, impulse responses are valid).", "",
  to_markdown(stability)
)
writeLines(markdown, file.path(TABLES, "model_diagnostics.md"))

cat("\nResidual autocorrelation:\n"); print(as.data.frame(autocorrelation), row.names = FALSE, digits = 3)
cat("\nCross-sectional dependence:\n"); print(as.data.frame(cross_dependence), row.names = FALSE, digits = 3)
cat("\nStability:\n"); print(as.data.frame(stability), row.names = FALSE, digits = 3)
cat("\nWrote", file.path(TABLES, "model_diagnostics.md"), "\n")
