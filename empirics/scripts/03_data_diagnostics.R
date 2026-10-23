# =============================================================================
# 03_data_diagnostics.R — properties of the data BEFORE estimation
# (empirics/ANALYSIS_PLAN.md, section 6a: stationarity and persistence protocol)
#
#   D1  Classification of every state x series: constant / too short / gaps / testable
#   D2  Panel unit-root tests on the testable series
#         - unit-level ADF regressions, lag length by AIC (0 to MAX_ADF_LAGS)
#         - Maddala-Wu (Fisher chi2) and Choi (inverse normal Z) combinations of the
#           unit p-values (MacKinnon distribution via urca::punitroot)
#         - share of states rejecting a unit root at 5%
#         - Pesaran (2007) CIPS test, robust to common shocks (balanced sub-panel)
#         - everything also on year-demeaned series (= the year effects of the model)
#   D3  Persistence of the series: pooled within-AR(1) coefficient (with the
#       Nickell bias correction) and, for 0/1 series, switching probabilities
#   D4  Panel balance (needed for the Juodis-Karavias-Sarafidis test, script 05)
#   D5  Lag-length criteria (AIC, BIC) of the bivariate VAR for 1..MAX_LAGS lags
#
# Principle (plan 6a): these tests DESCRIBE the series; they are not a sample
# filter. States with constant series (e.g. never in conflict) stay in the
# estimation sample: a constant series has no unit root, it is only untestable.
#
# Packages: plm (critical values of CIPS), urca (MacKinnon p-values). If urca is
# missing:  renv::install("urca"); renv::snapshot(type = "all")
#
# Input : empirics/results/data/analysis_panel.csv (from 01_prepare_sample.R)
# Output: empirics/results/tables/data_diagnostics.md
#         empirics/results/tables/diag_series_classes.csv, diag_unit_root.csv,
#         diag_unit_root_by_state.csv, diag_persistence.csv, diag_balance.csv,
#         diag_lag_selection.csv
# =============================================================================

source(here::here("empirics", "scripts", "00_setup.R"))
source(here::here("empirics", "scripts", "functions.R"))
if (!requireNamespace("urca", quietly = TRUE)) {
  stop('Package "urca" is needed for the unit-root p-values. Run in R: ',
       'renv::install("urca"); renv::snapshot(type = "all")')
}
suppressPackageStartupMessages(library(plm))

analysis <- read_csv(file.path(SAMPLE_DATA, "analysis_panel.csv"), show_col_types = FALSE)
window   <- analysis %>% filter(in_window)

SERIES <- c(new_sanction = "New sanction (0/1)",
            n_new_cases  = "New sanction cases (count)",
            viol_inc     = "Conflict (0/1)",
            viol_lev     = "log(1 + deaths per 100,000)")
BINARY_SERIES   <- c("new_sanction", "viol_inc")
MAX_ADF_LAGS    <- 2         # lags of the differenced series in the unit-level ADF regressions
CADF_TRUNCATION <- c(-6.19, 2.61)   # Pesaran (2007): truncation bounds of unit CADF statistics, intercept case


# =============================================================================
# Helper functions
# =============================================================================

# Remove the cross-state mean of each year (the year effects of the model)
demean_by_year <- function(data, variable) {
  data %>% group_by(yr) %>% mutate("{variable}" := .data[[variable]] - mean(.data[[variable]])) %>% ungroup()
}

# Classify one state's series: why it can or cannot be tested
classify_series <- function(values, years) {
  if (length(values) < MIN_OBS)            return("too short")
  if (any(diff(years) != 1))               return("gaps")
  if (length(unique(values)) == 1)         return("constant")
  if (sum(values != stats::median(values)) < 3) return("almost constant")   # 1-2 deviating years
  "testable"
}

# Unit-level ADF regression with intercept:
#   dy_t = a + rho * y_t-1 + sum_j c_j dy_t-j + e_t
# The number of lagged differences (0..max_lags) is chosen by AIC on a common sample.
# Returns the t-statistic of rho and the lag chosen; NA if the regression is degenerate.
adf_unit <- function(y, max_lags = MAX_ADF_LAGS) {
  n  <- length(y)
  dy <- c(NA, diff(y))
  design <- data.frame(dy = dy, y_lag = c(NA, y[-n]))
  for (j in seq_len(max_lags)) design[[paste0("dy_lag", j)]] <- c(rep(NA, j), dy[seq_len(n - j)])
  design <- design[(max_lags + 2):n, ]               # common sample for all lag choices

  fits <- lapply(0:max_lags, function(p) {
    terms <- c("y_lag", if (p > 0) paste0("dy_lag", seq_len(p)))
    lm(reformulate(terms, response = "dy"), data = design)
  })
  best <- fits[[which.min(sapply(fits, AIC))]]
  coef_table <- summary(best)$coefficients
  if (!"y_lag" %in% rownames(coef_table) || sigma(best) < 1e-10) {
    return(c(t_stat = NA, lags = NA))
  }
  t_stat <- coef_table["y_lag", "t value"]
  c(t_stat = if (is.finite(t_stat)) t_stat else NA, lags = length(coef(best)) - 2)
}

# MacKinnon (1996) asymptotic p-value of an ADF t-statistic (intercept case); NA stays NA
mackinnon_p_value <- function(t_stat) {
  p <- rep(NA_real_, length(t_stat))
  ok <- !is.na(t_stat)
  if (any(ok)) p[ok] <- urca::punitroot(t_stat[ok], N = Inf, trend = "c", statistic = "t")
  p
}

# Pesaran (2007) CADF for one state: ADF regression augmented with the
# cross-section mean (ybar) to absorb common shocks; one lagged difference.
cadf_unit <- function(y, ybar) {
  n <- length(y)
  design <- data.frame(dy = c(NA, diff(y)), y_lag = c(NA, y[-n]),
                       ybar_lag = c(NA, ybar[-n]), dybar = c(NA, diff(ybar)))
  design$dy_lag1    <- c(NA, design$dy[-n])
  design$dybar_lag1 <- c(NA, design$dybar[-n])
  fit <- lm(dy ~ y_lag + ybar_lag + dybar + dy_lag1 + dybar_lag1, data = design)
  if (sigma(fit) < 1e-10) return(NA)
  t_stat <- summary(fit)$coefficients["y_lag", "t value"]
  if (is.finite(t_stat)) t_stat else NA
}

# All unit-root statistics for one series (raw or year-demeaned).
# `classes`: classification of the RAW series by state. The year-demeaned version
# must test the same states: demeaning turns an all-zero series into minus the
# year means, which is no longer constant but carries no information of its own.
unit_root_tests <- function(data, variable, version, classes = NULL) {
  by_state <- data %>%
    filter(!is.na(.data[[variable]])) %>%
    arrange(gwcode, yr) %>%
    group_by(gwcode, gw_name) %>%
    summarise(class = if (is.null(classes)) classify_series(.data[[variable]], yr)
                      else classes$class[match(first(gwcode), classes$gwcode)],
              adf   = list(if (class == "testable") adf_unit(.data[[variable]]) else c(t_stat = NA, lags = NA)),
              .groups = "drop") %>%
    mutate(t_stat = sapply(adf, `[[`, "t_stat"),
           adf_lags = sapply(adf, `[[`, "lags"),
           degenerate = class == "testable" & is.na(t_stat),
           p_value = mackinnon_p_value(t_stat)) %>%
    select(-adf) %>%
    mutate(variable = variable, version = version, .before = 1)

  p <- by_state$p_value[!is.na(by_state$p_value)]
  p <- pmin(pmax(p, 1e-12), 1 - 1e-12)                       # keep log() and qnorm() finite
  n_tested <- length(p)

  # CIPS on the balanced sub-panel of testable states
  balanced <- data %>%
    filter(gwcode %in% by_state$gwcode[by_state$class == "testable" & !by_state$degenerate]) %>%
    filter(!is.na(.data[[variable]])) %>%
    group_by(gwcode) %>% filter(n() == length(SAMPLE_YEARS)) %>% ungroup()
  cross_mean <- balanced %>% group_by(yr) %>% summarise(ybar = mean(.data[[variable]]), .groups = "drop")
  cadf <- balanced %>% left_join(cross_mean, by = "yr") %>% arrange(gwcode, yr) %>%
    group_by(gwcode) %>% summarise(t = cadf_unit(.data[[variable]], ybar), .groups = "drop") %>%
    filter(!is.na(t))
  cips <- mean(pmin(pmax(cadf$t, CADF_TRUNCATION[1]), CADF_TRUNCATION[2]))
  cips_p <- tryCatch(plm:::critvals.cips(stat = cips, n = nrow(cadf), T. = length(SAMPLE_YEARS),
                                         type = "drift", truncated = TRUE),
                     error = function(e) NA)

  summary_row <- tibble(
    variable = variable, version = version,
    states_total     = nrow(by_state),
    constant         = sum(by_state$class == "constant"),
    almost_constant  = sum(by_state$class == "almost constant"),
    too_short_or_gaps = sum(by_state$class %in% c("too short", "gaps")),
    degenerate       = sum(by_state$degenerate),
    states_tested    = n_tested,
    share_reject_5pct = mean(p < 0.05),
    maddala_wu_chi2  = -2 * sum(log(p)),
    maddala_wu_df    = 2 * n_tested,
    maddala_wu_p     = pchisq(-2 * sum(log(p)), df = 2 * n_tested, lower.tail = FALSE),
    choi_z           = sum(qnorm(p)) / sqrt(n_tested),
    choi_p           = pnorm(sum(qnorm(p)) / sqrt(n_tested)),
    cips             = cips,
    cips_states      = nrow(cadf),
    cips_p           = as.character(cips_p)
  )
  list(summary = summary_row, by_state = by_state)
}


# =============================================================================
# D1 + D2. Classification and unit-root tests (raw and year-demeaned)
# =============================================================================
unit_root_summary <- list(); unit_root_states <- list()
for (variable in names(SERIES)) {
  raw      <- window %>% select(gwcode, gw_name, yr, all_of(variable)) %>% filter(!is.na(.data[[variable]]))
  demeaned <- demean_by_year(raw, variable)
  raw_result <- unit_root_tests(raw, variable, "raw")
  for (version in c("raw", "year-demeaned")) {
    result <- if (version == "raw") raw_result else
      unit_root_tests(demeaned, variable, version, classes = raw_result$by_state %>% select(gwcode, class))
    unit_root_summary[[paste(variable, version)]] <- result$summary
    unit_root_states[[paste(variable, version)]]  <- result$by_state
  }
}
unit_root_summary <- bind_rows(unit_root_summary)
unit_root_states  <- bind_rows(unit_root_states)
series_classes <- unit_root_states %>% filter(version == "raw") %>% count(variable, class) %>%
  pivot_wider(names_from = class, values_from = n, values_fill = 0)

write_csv(series_classes,    file.path(TABLES, "diag_series_classes.csv"))
write_csv(unit_root_summary, file.path(TABLES, "diag_unit_root.csv"))
write_csv(unit_root_states,  file.path(TABLES, "diag_unit_root_by_state.csv"))


# =============================================================================
# D3. Persistence
#   Pooled within (fixed-effects) AR(1): y_it = rho y_i,t-1 + state FE + year FE.
#   FE estimates of rho are biased down by about (1 + rho) / (T - 1) (Nickell 1981);
#   the corrected value adds that back. For 0/1 series: switching probabilities.
# =============================================================================
persistence_rows <- list()
for (variable in names(SERIES)) {
  with_lag <- add_lags(analysis, variable, 1) %>%
    filter(in_window, !is.na(.data[[variable]]), !is.na(.data[[paste0(variable, "_l1")]]))
  fe_ar1 <- lm(reformulate(c(paste0(variable, "_l1"), "factor(gwcode)", "factor(yr)"), response = variable),
               data = with_lag)
  rho <- coef(fe_ar1)[[paste0(variable, "_l1")]]
  average_T <- nrow(with_lag) / n_distinct(with_lag$gwcode)
  current  <- with_lag[[variable]]
  previous <- with_lag[[paste0(variable, "_l1")]]
  persistence_rows[[variable]] <- tibble(
    variable = variable,
    fe_ar1 = rho,
    fe_ar1_nickell_corrected = rho + (1 + rho) / (average_T - 1),
    pooled_ar1_no_fe = cor(current, previous),
    p_on_given_off = if (variable %in% BINARY_SERIES) mean(current[previous == 0] == 1) else NA,
    p_on_given_on  = if (variable %in% BINARY_SERIES) mean(current[previous == 1] == 1) else NA,
    observations = nrow(with_lag), average_T = average_T
  )
}
persistence <- bind_rows(persistence_rows)
write_csv(persistence, file.path(TABLES, "diag_persistence.csv"))


# =============================================================================
# D4. Panel balance: states with complete main variables in every window year
# =============================================================================
MAIN_VARIABLES <- names(SERIES)
balance <- window %>%
  group_by(gwcode, gw_name) %>%
  summarise(complete_years = sum(complete.cases(across(all_of(MAIN_VARIABLES)))), .groups = "drop") %>%
  mutate(balanced = complete_years == length(SAMPLE_YEARS))
write_csv(balance, file.path(TABLES, "diag_balance.csv"))


# =============================================================================
# D5. Lag-length criteria of the bivariate VAR (OLS, state and year FE, no controls)
#   Same sample for every lag length (MAX_LAGS lags available). System criteria:
#   AIC = log|Sigma| + 2 m / n,  BIC = log|Sigma| + m log(n) / n,
#   Sigma = residual covariance of the two equations, m = number of lag coefficients.
# =============================================================================
SPECIFICATIONS <- list(incidence = c(sanction = "new_sanction", violence = "viol_inc"),
                       levels    = c(sanction = "n_new_cases",  violence = "viol_lev"))
lag_selection_rows <- list()
for (spec_name in names(SPECIFICATIONS)) {
  sanction <- SPECIFICATIONS[[spec_name]][["sanction"]]
  violence <- SPECIFICATIONS[[spec_name]][["violence"]]
  sample_all_lags <- add_lags(analysis, c(sanction, violence), MAX_LAGS) %>%
    filter(in_window) %>%
    filter(if_all(all_of(c(sanction, violence, lag_names(sanction, MAX_LAGS), lag_names(violence, MAX_LAGS))),
                  ~ !is.na(.x)))
  for (n_lags in seq_len(MAX_LAGS)) {
    residuals_matrix <- cbind(
      residuals(fit_reaction_function(sample_all_lags, violence, sanction, n_lags)),
      residuals(fit_reaction_function(sample_all_lags, sanction, violence, n_lags)))
    n <- nrow(residuals_matrix)
    log_det <- log(det(crossprod(residuals_matrix) / n))
    m <- 2 * 2 * n_lags                       # lag coefficients in the system (FE identical for all n_lags)
    lag_selection_rows[[paste(spec_name, n_lags)]] <- tibble(
      specification = spec_name, n_lags = n_lags, observations = n,
      aic = log_det + 2 * m / n, bic = log_det + m * log(n) / n)
  }
}
lag_selection <- bind_rows(lag_selection_rows) %>%
  group_by(specification) %>%
  mutate(lowest_aic = aic == min(aic), lowest_bic = bic == min(bic)) %>% ungroup()
write_csv(lag_selection, file.path(TABLES, "diag_lag_selection.csv"))


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

unit_root_display <- unit_root_summary %>%
  transmute(variable = SERIES[variable], version,
            `states tested` = states_tested,
            `not testable (constant / almost / short / degenerate)` =
              paste(constant, almost_constant, too_short_or_gaps, degenerate, sep = " / "),
            `share rejecting at 5%` = share_reject_5pct,
            `Maddala–Wu χ² (p)` = sprintf("%.1f (%.3f)", maddala_wu_chi2, maddala_wu_p),
            `Choi Z (p)` = sprintf("%.2f (%.3f)", choi_z, choi_p),
            `CIPS (states, p)` = sprintf("%.2f (%d, %s)", cips, cips_states, cips_p))

markdown <- c(
  "# Data diagnostics (before estimation)", "",
  paste0("Generated by `empirics/scripts/03_data_diagnostics.R` on ", format(Sys.time(), "%Y-%m-%d %H:%M"),
         ". Window ", min(SAMPLE_YEARS), "–", max(SAMPLE_YEARS), "."), "",
  "## D1. Which series can be tested? (number of states)", "",
  "Constant = same value in every year (e.g. never in conflict); almost constant = only 1–2 deviating years. ",
  "These states stay in the estimation sample (plan 6a); they only cannot be tested.", "",
  to_markdown(series_classes %>% mutate(variable = SERIES[variable])),
  "## D2. Panel unit-root tests (H0: unit root in every state)", "",
  "Unit-level ADF with intercept, lags by AIC (0–2); Maddala–Wu and Choi combine the unit p-values; ",
  "CIPS (Pesaran 2007) adds cross-section means against common shocks (balanced sub-panel, truncated CADF; ",
  "p-value from Pesaran's tables, reported as a bound). Small p = reject the unit root = stationary.", "",
  to_markdown(unit_root_display),
  "## D3. Persistence", "",
  "FE AR(1) with state and year effects; Nickell-corrected = FE + (1 + ρ)/(T − 1). ",
  "P(on | off), P(on | on): probability that a 0/1 series is 1 this year given last year's value.", "",
  to_markdown(persistence %>% mutate(variable = SERIES[variable])),
  "## D4. Panel balance", "",
  paste0(sum(balance$balanced), " of ", nrow(balance), " states have complete main variables in all ",
         length(SAMPLE_YEARS), " years (balanced sub-panel for script 05). ",
         "Unbalanced: states created or dissolved during the window."), "",
  "## D5. Lag length of the bivariate VAR (OLS, state and year FE, common sample)", "",
  to_markdown(lag_selection, digits = 4)
)
writeLines(markdown, file.path(TABLES, "data_diagnostics.md"))

cat("\nSeries classes:\n");      print(as.data.frame(series_classes), row.names = FALSE)
cat("\nUnit-root tests:\n");     print(as.data.frame(unit_root_display), row.names = FALSE)
cat("\nPersistence:\n");         print(as.data.frame(persistence), row.names = FALSE, digits = 3)
cat("\nBalanced states:", sum(balance$balanced), "of", nrow(balance), "\n")
cat("\nLag selection:\n");       print(as.data.frame(lag_selection), row.names = FALSE, digits = 4)
cat("\nWrote", file.path(TABLES, "data_diagnostics.md"), "\n")
