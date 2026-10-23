# =============================================================================
# 11_gdelt.R — robustness: the whole analysis with GDELT instead of UCDP violence
# (empirics/ANALYSIS_PLAN.md, section 2 "Violence, alternative source" and R12)
#
# Why GDELT (plan, section 2):
#   (i)   independent source: counts of media-reported events instead of UCDP's
#         fatality coding, so agreement is not an artefact of one dataset;
#   (ii)  measures violence BELOW the UCDP 25-death threshold (clashes, assaults);
#   (iii) starts in 1979, so the late Cold War can be added.
#
# Violence measures (plan, section 2; data/README.md G1-G13):
#   gdelt_viol = assault + fight + mass_violence events per 1,000 GDELT events in the
#                country-year (normalised for media volume, G13). COERCE is left out:
#                it is reserved for the anticipation proxy (R6).
#   gdelt_lev  = gdelt_viol / 10 = violent events in % of all reported events (levels)
#   gdelt_inc  = 1 if gdelt_viol is above the state's own 1979-2021 median (incidence, D6)
#
# Samples (R12):
#   ucdp_years  1991-2019: the estimation years of Table 1 (script 04), so the only
#               difference to the main results is the violence measure (and the sample rule)
#   full_gdelt  1981-2021: the whole GDELT period (1979-80 only serve as lags)
#   Thin coverage check: GDELT shares of state-years with very few reported events
#   (microstates, early years) are noisy, so Table 1 is repeated without state-years
#   with fewer than THIN_COVERAGE_EVENTS GDELT events.
#
# Contents (each part mirrors one main script; same functions, same layout):
#   Part 1  sample, variables, validation against UCDP          (01, 02)
#   Part 2  stationarity and persistence of the GDELT measures  (03, short version)
#   Part 3  reaction functions and Granger tests, OLS + jackknife (04, Table 1)
#   Part 4  lag grid                                             (04, Table 2)
#   Part 5  empirical response functions (JP Fig. 2)            (07)
#   (the LP-DiD event study with GDELT is in 12_lpdid.R: extension, not base case)
#   Part 6  impulse responses with country-cluster bootstrap     (08)
#   Part 7  report: gdelt_results.md, side by side with the UCDP results
#
# Input : data/processed/sanctions_violence/sanctions_violence_panel.csv
#         empirics/results/tables/table1_granger.csv (UCDP results from 04, for the comparison)
# Output: empirics/results/tables/gdelt_results.md           report
#         empirics/results/tables/gdelt_*.csv                  all numbers
#         empirics/results/figures/fig14_gdelt_cumulative_irf.png
#         empirics/results/figures/fig15_gdelt_response_functions.png
#         empirics/results/data/gdelt_analysis_panel.csv
# Runtime (test run, 2026-10-22): Parts 1-5 about 5 minutes; Part 6 about 7 seconds
#   per bootstrap draw for all eight VARs. Default 99 draws: about 17 minutes in total.
#   Set GDELT_BOOT_DRAWS=999 for the final version (about 2 hours), or e.g.
#   GDELT_BOOT_DRAWS=10 for a quick test.
# =============================================================================

source(here::here("empirics", "scripts", "00_setup.R"))
source(here::here("empirics", "scripts", "functions.R"))
if (!requireNamespace("urca", quietly = TRUE)) {
  stop('Package "urca" is needed for the unit-root p-values. Run in R: ',
       'renv::install("urca"); renv::snapshot(type = "all")')
}

# --- choices of this script ------------------------------------------------------
GDELT_YEARS          <- 1979:2021    # GDELT coverage (data/README.md G7)
THIN_COVERAGE_EVENTS <- 100          # coverage check: drop state-years with fewer GDELT events
N_LAGS               <- VAR_LAGS     # lag length of the VAR, as in the main analysis
IRF_HORIZON          <- 10
N_BOOT               <- as.integer(Sys.getenv("GDELT_BOOT_DRAWS", "99"))
LEADS <- 3; HORIZON <- 8                        # response functions, as in 07

WINDOWS <- list(
  ucdp_years = list(years = (min(SAMPLE_YEARS) + VAR_LAGS):max(SAMPLE_YEARS),
                    label = "GDELT, 1991-2019 (years of Table 1)"),
  full_gdelt = list(years = (min(GDELT_YEARS) + VAR_LAGS):max(GDELT_YEARS),
                    label = "GDELT, 1981-2021 (full period)")
)
SPECIFICATIONS <- list(
  incidence = list(sanction = "new_sanction", violence = "gdelt_inc"),
  levels    = list(sanction = "n_new_cases",  violence = "gdelt_lev")
)
CONTROL_SETS <- list(with_controls = CONTROLS, no_controls = character(0))
MAIN_VARIABLES <- c("new_sanction", "n_new_cases", "gdelt_inc", "gdelt_lev")

VARIABLE_LABELS <- c(gdelt_inc = "GDELT violence above own median (0/1)",
                     gdelt_lev = "GDELT violent events (% of all events)")

# Markdown table from a data frame (numbers rounded)
to_markdown <- function(table, digits = 3) {
  table <- table %>% mutate(across(where(is.numeric), ~ round(.x, digits)))
  c(paste0("| ", paste(names(table), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(table)), collapse = "|"), "|"),
    apply(table, 1, function(row) paste0("| ", paste(ifelse(is.na(row), "", trimws(row)), collapse = " | "), " |")),
    "")
}


# =============================================================================
# Part 1. Sample, variables, validation against UCDP
# =============================================================================
panel <- read_panel()

gdelt_panel <- panel %>%
  filter(yr >= min(GDELT_YEARS) - MAX_LAGS, yr <= max(GDELT_YEARS)) %>%
  transmute(
    gwcode, gw_name, yr,
    # sanctions: same GSDB flow variables as in the main analysis
    new_sanction, n_new_cases, n_cases_received,
    # GDELT violence (missing outside 1979-2021 and for non-separable states, G7/G11)
    gdelt_viol = assault_norm1000 + fight_norm1000 + mass_violence_norm1000,
    gdelt_total_events,
    # UCDP violence, only for the validation below
    ucdp_inc = as.integer(cumulative_total_deaths_in_orgvio_best >= CONFLICT_MIN_DEATHS),
    ucdp_lev = log1p(cumulative_total_deaths_in_orgvio_best_pc),
    # inputs for the controls (as in 01)
    gdp = gdp_ext, v2x_polyarchy, ex_yugo_1991_2016
  ) %>%
  arrange(gwcode, yr) %>%
  group_by(gwcode) %>%
  mutate(gdelt_state_median = median(gdelt_viol[yr %in% GDELT_YEARS], na.rm = TRUE)) %>%   # D6
  ungroup() %>%
  mutate(gdelt_lev = gdelt_viol / 10,
         gdelt_inc = as.integer(gdelt_viol > gdelt_state_median))

# Controls, lagged one year (identical construction to 01_prepare_sample.R)
gdelt_panel$gdp_growth      <- log(gdelt_panel$gdp) - log(lag_by_year(gdelt_panel, "gdp", 1))
gdelt_panel$ctrl_stock      <- lag_by_year(gdelt_panel, "n_cases_received", 1)
gdelt_panel$ctrl_gdp_growth <- lag_by_year(gdelt_panel, "gdp_growth", 1)
gdelt_panel$ctrl_democracy  <- lag_by_year(gdelt_panel, "v2x_polyarchy", 1)
write_csv(gdelt_panel, file.path(SAMPLE_DATA, "gdelt_analysis_panel.csv"))

# Data of one window: `in_window` marks the estimation years; states with fewer than
# MIN_OBS complete years of the main variables in the window are dropped (rule of 01).
# thin_coverage_removed = TRUE sets the GDELT measures to missing in state-years with
# fewer than THIN_COVERAGE_EVENTS reported events.
window_data <- function(window_name, thin_coverage_removed = FALSE) {
  data <- gdelt_panel %>% mutate(in_window = yr %in% WINDOWS[[window_name]]$years)
  if (thin_coverage_removed) {
    thin <- !is.na(data$gdelt_total_events) & data$gdelt_total_events < THIN_COVERAGE_EVENTS
    data$gdelt_lev[thin] <- NA
    data$gdelt_inc[thin] <- NA
  }
  complete_years <- data %>%
    filter(in_window) %>%
    group_by(gwcode) %>%
    summarise(complete = sum(complete.cases(across(all_of(MAIN_VARIABLES)))), .groups = "drop")
  data %>% filter(gwcode %in% complete_years$gwcode[complete_years$complete >= MIN_OBS])
}

# --- sample overview ------------------------------------------------------------------
sample_rows <- list()
for (window_name in names(WINDOWS)) {
  data <- window_data(window_name) %>% filter(in_window)
  sample_rows[[window_name]] <- tibble(
    window = WINDOWS[[window_name]]$label, states = n_distinct(data$gwcode), state_years = nrow(data),
    mean_gdelt_lev = mean(data$gdelt_lev, na.rm = TRUE), mean_gdelt_inc = mean(data$gdelt_inc, na.rm = TRUE),
    share_zero_gdelt = mean(data$gdelt_viol == 0, na.rm = TRUE),
    share_thin_coverage = mean(data$gdelt_total_events < THIN_COVERAGE_EVENTS, na.rm = TRUE),
    mean_new_sanction = mean(data$new_sanction, na.rm = TRUE))
}
gdelt_sample <- bind_rows(sample_rows)
write_csv(gdelt_sample, file.path(TABLES, "gdelt_sample.csv"))

# --- validation: does GDELT track UCDP violence? (years where both exist) ------------
overlap <- gdelt_panel %>%
  filter(yr %in% SAMPLE_YEARS, !is.na(gdelt_lev), !is.na(ucdp_lev)) %>%
  group_by(gwcode) %>%
  mutate(gdelt_within = gdelt_lev - mean(gdelt_lev), ucdp_lev_within = ucdp_lev - mean(ucdp_lev),
         ucdp_inc_within = ucdp_inc - mean(ucdp_inc)) %>%
  ungroup()
gdelt_validation <- tibble(
  comparison = c("corr(GDELT %, UCDP log deaths), pooled",
                 "corr(GDELT %, UCDP log deaths), within states",
                 "corr(GDELT %, UCDP conflict 0/1), pooled",
                 "corr(GDELT %, UCDP conflict 0/1), within states",
                 "P(GDELT incidence = 1 | UCDP conflict year)",
                 "P(GDELT incidence = 1 | no UCDP conflict)",
                 "P(UCDP conflict | GDELT incidence = 1)"),
  value = c(cor(overlap$gdelt_lev, overlap$ucdp_lev),
            cor(overlap$gdelt_within, overlap$ucdp_lev_within),
            cor(overlap$gdelt_lev, overlap$ucdp_inc),
            cor(overlap$gdelt_within, overlap$ucdp_inc_within),
            mean(overlap$gdelt_inc[overlap$ucdp_inc == 1]),
            mean(overlap$gdelt_inc[overlap$ucdp_inc == 0]),
            mean(overlap$ucdp_inc[overlap$gdelt_inc == 1])))
write_csv(gdelt_validation, file.path(TABLES, "gdelt_validation.csv"))
cat("\nGDELT vs UCDP (", min(SAMPLE_YEARS), "-", max(SAMPLE_YEARS), "):\n", sep = "")
print(as.data.frame(gdelt_validation), row.names = FALSE, digits = 3)


# =============================================================================
# Part 2. Stationarity and persistence (short version of 03)
# =============================================================================

# ADF regression for one state, intercept, 0-2 lagged differences chosen by AIC
# (same as adf_unit() in 03_data_diagnostics.R). Returns the t-statistic of rho or NA.
adf_t_statistic <- function(y, max_lags = 2) {
  n  <- length(y)
  dy <- c(NA, diff(y))
  design <- data.frame(dy = dy, y_lag = c(NA, y[-n]))
  for (j in seq_len(max_lags)) design[[paste0("dy_lag", j)]] <- c(rep(NA, j), dy[seq_len(n - j)])
  design <- design[(max_lags + 2):n, ]
  fits <- lapply(0:max_lags, function(p) {
    lm(reformulate(c("y_lag", if (p > 0) paste0("dy_lag", seq_len(p))), response = "dy"), data = design)
  })
  best <- fits[[which.min(sapply(fits, AIC))]]
  coefficients <- summary(best)$coefficients
  if (!"y_lag" %in% rownames(coefficients) || sigma(best) < 1e-10) return(NA)
  t_stat <- coefficients["y_lag", "t value"]
  if (is.finite(t_stat)) t_stat else NA
}

# Maddala-Wu and Choi tests from the state ADF p-values. Only states whose series
# has no gaps, at least MIN_OBS years and at least 3 years off its median are tested
# (constant / almost constant series cannot be tested; see 03, D1). year_demeaned =
# TRUE removes the year means first (= the year effects of the model).
panel_unit_root <- function(data, variable, year_demeaned = FALSE) {
  data <- data %>% filter(in_window, !is.na(.data[[variable]])) %>% arrange(gwcode, yr)
  testable_states <- data %>% group_by(gwcode) %>%
    summarise(ok = n() >= MIN_OBS & all(diff(yr) == 1) &
                sum(.data[[variable]] != median(.data[[variable]])) >= 3, .groups = "drop") %>%
    filter(ok) %>% pull(gwcode)
  if (year_demeaned) {
    data <- data %>% group_by(yr) %>% mutate("{variable}" := .data[[variable]] - mean(.data[[variable]])) %>% ungroup()
  }
  t_stats <- data %>% filter(gwcode %in% testable_states) %>% group_by(gwcode) %>%
    summarise(t_stat = adf_t_statistic(.data[[variable]]), .groups = "drop") %>% pull(t_stat)
  t_stats <- t_stats[!is.na(t_stats)]
  p <- urca::punitroot(t_stats, N = Inf, trend = "c", statistic = "t")
  p <- pmin(pmax(p, 1e-12), 1 - 1e-12)
  maddala_wu <- -2 * sum(log(p))
  choi_z     <- sum(qnorm(p)) / sqrt(length(p))
  tibble(variable = variable, version = ifelse(year_demeaned, "year-demeaned", "raw"),
         states_tested = length(p), share_rejecting_5pct = mean(p < 0.05),
         maddala_wu = maddala_wu, maddala_wu_p = pchisq(maddala_wu, 2 * length(p), lower.tail = FALSE),
         choi_z = choi_z, choi_p = pnorm(choi_z))
}

# FE AR(1) with state and year effects, Nickell-corrected (as in 03, D3);
# for 0/1 series also the switching probabilities
persistence <- function(data, variable) {
  data <- data %>% mutate(lagged = lag_by_year(data, variable, 1)) %>%
    filter(in_window, !is.na(.data[[variable]]), !is.na(lagged))
  fe_ar1 <- coef(lm(reformulate(c("lagged", "factor(gwcode)", "factor(yr)"), response = variable), data = data))[["lagged"]]
  average_T <- nrow(data) / n_distinct(data$gwcode)
  is_binary <- all(data[[variable]] %in% c(0, 1))
  tibble(variable = variable, fe_ar1 = fe_ar1,
         fe_ar1_nickell_corrected = fe_ar1 + (1 + fe_ar1) / (average_T - 1),
         p_on_given_off = if (is_binary) mean(data[[variable]][data$lagged == 0]) else NA,
         p_on_given_on  = if (is_binary) mean(data[[variable]][data$lagged == 1]) else NA,
         within_sd = sd(data[[variable]] - ave(data[[variable]], data$gwcode)))
}

stationarity_rows <- list(); persistence_rows <- list()
for (window_name in names(WINDOWS)) {
  data <- window_data(window_name)
  for (variable in c("gdelt_inc", "gdelt_lev")) {
    for (demeaned in c(FALSE, TRUE)) {
      stationarity_rows[[paste(window_name, variable, demeaned)]] <-
        panel_unit_root(data, variable, demeaned) %>% mutate(window = WINDOWS[[window_name]]$label, .before = 1)
    }
    persistence_rows[[paste(window_name, variable)]] <-
      persistence(data, variable) %>% mutate(window = WINDOWS[[window_name]]$label, .before = 1)
  }
}
gdelt_stationarity <- bind_rows(stationarity_rows)
gdelt_persistence  <- bind_rows(persistence_rows)
write_csv(gdelt_stationarity, file.path(TABLES, "gdelt_stationarity.csv"))
write_csv(gdelt_persistence,  file.path(TABLES, "gdelt_persistence.csv"))


# =============================================================================
# Part 3. Reaction functions and Granger tests (Table 1 with GDELT)
# =============================================================================

# Both equations of one VAR, OLS and half-panel jackknife: Granger tests, sums of
# the cross-lag coefficients, stability. Returns list(granger = rows, coefficients = rows).
estimate_var <- function(estimation_sample, sanction, violence, controls, labels) {
  equations <- list(violence = list(outcome = violence, other = sanction),
                    sender   = list(outcome = sanction, other = violence))
  estimates <- lapply(equations, function(eq) list(
    OLS       = fit_reaction_function(estimation_sample, eq$outcome, eq$other, N_LAGS, controls),
    jackknife = half_panel_jackknife(estimation_sample, eq$outcome, eq$other, N_LAGS, controls)))

  granger <- list(); coefficients <- list()
  for (estimator in c("OLS", "jackknife")) {
    var_root <- largest_var_root(coef(estimates$violence[[estimator]]), coef(estimates$sender[[estimator]]),
                                 violence, sanction, N_LAGS)
    for (equation_name in names(equations)) {
      model <- estimates[[equation_name]][[estimator]]
      other <- equations[[equation_name]]$other
      test  <- wald_test(model, lag_names(other, N_LAGS))
      granger[[paste(estimator, equation_name)]] <- bind_cols(labels, tibble(
        estimator = estimator, equation = equation_name,
        chi2 = test$chi2, df = test$df, p_value = test$p_value,
        sum_cross_lags = test$sum_coef, sum_cross_se = test$sum_se,
        n_obs = nobs(estimates[[equation_name]]$OLS), n_states = n_distinct(estimation_sample$gwcode),
        first_year = min(estimation_sample$yr), last_year = max(estimation_sample$yr),
        largest_root = var_root))
      coefficients[[paste(estimator, equation_name)]] <- bind_cols(
        labels, tibble(estimator = estimator, equation = equation_name), coefficient_table(model))
    }
  }
  list(granger = bind_rows(granger), coefficients = bind_rows(coefficients))
}

# Three samples: both windows, plus the thin-coverage check on the Table 1 years
TABLE1_SAMPLES <- list(
  ucdp_years      = list(window = "ucdp_years", thin_removed = FALSE, label = WINDOWS$ucdp_years$label),
  full_gdelt      = list(window = "full_gdelt", thin_removed = FALSE, label = WINDOWS$full_gdelt$label),
  ucdp_years_thick = list(window = "ucdp_years", thin_removed = TRUE,
                          label = paste0("GDELT, 1991-2019, state-years with ≥ ", THIN_COVERAGE_EVENTS, " events"))
)

granger_rows <- list(); coefficient_rows <- list()
for (sample_name in names(TABLE1_SAMPLES)) {
  sample_spec <- TABLE1_SAMPLES[[sample_name]]
  data <- window_data(sample_spec$window, sample_spec$thin_removed)
  for (spec_name in names(SPECIFICATIONS)) {
    sanction <- SPECIFICATIONS[[spec_name]]$sanction
    violence <- SPECIFICATIONS[[spec_name]]$violence
    for (control_set in names(CONTROL_SETS)) {
      estimation_sample <- build_estimation_sample(data, sanction, violence, N_LAGS, CONTROL_SETS[[control_set]])
      labels <- tibble(sample = sample_name, sample_label = sample_spec$label,
                       specification = spec_name, control_set = control_set)
      results <- estimate_var(estimation_sample, sanction, violence, CONTROL_SETS[[control_set]], labels)
      granger_rows[[paste(sample_name, spec_name, control_set)]]     <- results$granger
      coefficient_rows[[paste(sample_name, spec_name, control_set)]] <- results$coefficients
      cat("Table 1 |", sample_name, spec_name, control_set, "|", nrow(estimation_sample), "obs\n")
    }
  }
}
gdelt_granger      <- bind_rows(granger_rows)
gdelt_coefficients <- bind_rows(coefficient_rows)
write_csv(gdelt_granger,      file.path(TABLES, "gdelt_granger.csv"))
write_csv(gdelt_coefficients, file.path(TABLES, "gdelt_coefficients.csv"))


# =============================================================================
# Part 4. Lag grid (Table 2 with GDELT): Granger tests for (own, other) lags 1..MAX_LAGS
#         on a common sample per window, OLS and jackknife
# =============================================================================
lag_grid <- expand.grid(own_lags = seq_len(MAX_LAGS), other_lags = seq_len(MAX_LAGS))
grid_rows <- list()
for (window_name in names(WINDOWS)) {
  data <- window_data(window_name)
  for (spec_name in names(SPECIFICATIONS)) {
    sanction <- SPECIFICATIONS[[spec_name]]$sanction
    violence <- SPECIFICATIONS[[spec_name]]$violence
    for (control_set in names(CONTROL_SETS)) {
      controls <- CONTROL_SETS[[control_set]]
      common_sample <- build_estimation_sample(data, sanction, violence, MAX_LAGS, controls)
      equations <- list(violence = list(outcome = violence, other = sanction),
                        sender   = list(outcome = sanction, other = violence))
      for (row in seq_len(nrow(lag_grid))) {
        own_lags <- lag_grid$own_lags[row]; other_lags <- lag_grid$other_lags[row]
        for (equation_name in names(equations)) {
          outcome <- equations[[equation_name]]$outcome; other <- equations[[equation_name]]$other
          ols_model <- fit_reaction_function(common_sample, outcome, other, own_lags, controls, n_lags_other = other_lags)
          jackknife <- half_panel_jackknife(common_sample, outcome, other, own_lags, controls, n_lags_other = other_lags)
          for (estimator in c("OLS", "jackknife")) {
            test <- wald_test(if (estimator == "OLS") ols_model else jackknife, lag_names(other, other_lags))
            grid_rows[[length(grid_rows) + 1]] <- tibble(
              window = window_name, specification = spec_name, control_set = control_set,
              estimator = estimator, equation = equation_name, own_lags = own_lags, other_lags = other_lags,
              chi2 = test$chi2, df = test$df, p_value = test$p_value, sum_cross_lags = test$sum_coef,
              bic = BIC(ols_model), n_obs = nobs(ols_model))
          }
        }
      }
      cat("Lag grid |", window_name, spec_name, control_set, "done\n")
    }
  }
}
gdelt_lag_grid <- bind_rows(grid_rows) %>%
  group_by(window, specification, control_set, estimator, equation) %>%
  mutate(lowest_bic = bic == min(bic)) %>% ungroup()
write_csv(gdelt_lag_grid, file.path(TABLES, "gdelt_lag_grid.csv"))


# =============================================================================
# Part 5. Empirical response functions (as in 07; Jaeger & Paserman Fig. 2)
#   Outcome k years after an event year minus all other years; raw and two-way FE.
#   The LP-DiD event study with GDELT is in 12_lpdid.R (extension, not base case).
# =============================================================================
RESPONSES <- list(
  list(name = "violence_after_sanction_incidence", event = "new_sanction", outcome = "gdelt_inc",
       label = "GDELT violence above median (0/1) after a new sanction"),
  list(name = "violence_after_sanction_levels",    event = "new_sanction", outcome = "gdelt_lev",
       label = "GDELT violent events (%) after a new sanction"),
  list(name = "sanctions_after_violence_incidence", event = "gdelt_inc",   outcome = "new_sanction",
       label = "New sanction (0/1) after an above-median GDELT violence year"),
  list(name = "sanctions_after_violence_levels",    event = "gdelt_inc",   outcome = "n_new_cases",
       label = "New sanction cases after an above-median GDELT violence year")
)

# Clustered estimate of one coefficient (as in 07)
clustered_estimate <- function(formula, data, term) {
  fit <- lm(formula, data = data)
  covariance <- sandwich::vcovCL(fit, cluster = data$gwcode, type = "HC1")
  estimate <- coef(fit)[[term]]; se <- sqrt(covariance[term, term])
  tibble(estimate = estimate, se = se, lower = estimate - 1.96 * se, upper = estimate + 1.96 * se,
         p_value = 2 * pnorm(-abs(estimate / se)), observations = nobs(fit), events = sum(data[[term]] == 1))
}
value_at <- function(data, variable, k) lag_by_year(data, variable, -k)   # k > 0: future value

# Outcome net of state and year means (as in 07)
two_way_demean <- function(data, variable) {
  rows <- !is.na(data[[variable]])
  fit <- lm(reformulate(c("factor(gwcode)", "factor(yr)"), response = variable), data = data[rows, ])
  out <- rep(NA_real_, nrow(data)); out[rows] <- residuals(fit); out
}

response_rows <- list()
for (window_name in names(WINDOWS)) {
  base_data <- window_data(window_name) %>% arrange(gwcode, yr)
  for (spec in RESPONSES) {
    data <- base_data
    data$outcome_fe <- two_way_demean(data, spec$outcome)
    for (k in -LEADS:HORIZON) {
      data$outcome_raw_k <- value_at(data, spec$outcome, k)
      data$outcome_fe_k  <- value_at(data, "outcome_fe", k)
      for (version in c("raw", "two-way FE")) {
        y <- if (version == "raw") "outcome_raw_k" else "outcome_fe_k"
        sample_k <- data %>% filter(in_window, !is.na(.data[[y]]), !is.na(.data[[spec$event]]))
        response_rows[[paste(window_name, spec$name, k, version)]] <- bind_cols(
          tibble(window = window_name, window_label = WINDOWS[[window_name]]$label,
                 response = spec$name, label = spec$label, version = version, horizon = k),
          clustered_estimate(reformulate(spec$event, response = y), sample_k, spec$event))
      }
    }
  }
}
gdelt_response_functions <- bind_rows(response_rows)
write_csv(gdelt_response_functions, file.path(TABLES, "gdelt_response_functions.csv"))

label_order <- sapply(RESPONSES, `[[`, "label")
WINDOW_COLOURS <- setNames(c(PAPER_COLOURS[["blue"]], PAPER_COLOURS[["orange"]]),
                           sapply(WINDOWS, `[[`, "label"))
figure_response <- ggplot(gdelt_response_functions %>%
                            filter(version == "two-way FE") %>%
                            mutate(label = factor(label, levels = label_order)),
                          aes(horizon, estimate, colour = window_label, fill = window_label)) +
  geom_hline(yintercept = 0, colour = "#52514e", linewidth = 0.3) +
  geom_vline(xintercept = 0, colour = "#8a8984", linewidth = 0.3, linetype = "dashed") +
  geom_ribbon(aes(ymin = lower, ymax = upper), alpha = 0.12, colour = NA) +
  geom_line(linewidth = 0.8) + geom_point(size = 1.1) +
  facet_wrap(~ label, scales = "free_y") +
  scale_colour_manual(values = WINDOW_COLOURS) + scale_fill_manual(values = WINDOW_COLOURS) +
  scale_x_continuous(breaks = -LEADS:HORIZON) +
  labs(title = "Empirical response functions with GDELT violence (two-way FE version)",
       x = "Years after the event (0 = event year)", y = "Difference in mean outcome",
       caption = paste0("As fig10, with GDELT instead of UCDP: outcome k years after an event year relative to other years, ",
                        "net of state and year means.\nEvent = new sanction (top) or above-median GDELT violence year (bottom). ",
                        "95% bands, SE clustered by state. Raw version in gdelt_response_functions.csv.")) +
  theme_paper()
save_figure(figure_response, "fig15_gdelt_response_functions.png", 10, 6.5)


# =============================================================================
# Part 6. Impulse responses with country-cluster bootstrap (as in 08)
#   Shock size: incidence = one unit (one new sanction / one above-median year);
#   levels: one new sanction case / ONE WITHIN-STATE STANDARD DEVIATION of gdelt_lev
#   (a 1-percentage-point shock would be tiny and hard to compare). Responses of
#   violence are in the units of the GDELT measure.
# =============================================================================

# Responses of one VAR for the three identification schemes (functions.R, as in 08)
var_responses <- function(data, sanction, violence, controls) {
  violence_model <- fit_reaction_function(data, violence, sanction, N_LAGS, controls, cluster_se = FALSE)
  sender_model   <- fit_reaction_function(data, sanction, violence, N_LAGS, controls, cluster_se = FALSE)
  residual_matrix <- cbind(residuals(violence_model), residuals(sender_model))
  Sigma <- crossprod(residual_matrix) / nrow(residual_matrix)
  Phi <- var_ma_coefficients(coef(violence_model), coef(sender_model), violence, sanction, N_LAGS, IRF_HORIZON)
  impacts <- impact_matrices(Sigma)
  bind_rows(lapply(names(impacts), function(identification)
    impulse_responses(Phi, impacts[[identification]]) %>% mutate(identification = identification)))
}
resample_states <- function(data) {
  drawn <- sample(unique(data$gwcode), n_distinct(data$gwcode), replace = TRUE)
  bind_rows(lapply(seq_along(drawn), function(i) data[data$gwcode == drawn[i], ] %>% mutate(gwcode = i)))
}

irf_rows <- list()
for (window_name in names(WINDOWS)) {
  data <- window_data(window_name)
  for (spec_name in names(SPECIFICATIONS)) {
    sanction <- SPECIFICATIONS[[spec_name]]$sanction
    violence <- SPECIFICATIONS[[spec_name]]$violence
    for (control_set in names(CONTROL_SETS)) {
      controls <- CONTROL_SETS[[control_set]]
      estimation_sample <- build_estimation_sample(data, sanction, violence, N_LAGS, controls)
      violence_shock <- if (spec_name == "levels") {
        sd(estimation_sample[[violence]] - ave(estimation_sample[[violence]], estimation_sample$gwcode))
      } else 1
      cat("IRF |", window_name, spec_name, control_set, "|", N_BOOT, "draws\n")

      set.seed(20261022)
      responses <- bind_rows(
        var_responses(estimation_sample, sanction, violence, controls) %>% mutate(draw = 0),   # point estimate
        bind_rows(lapply(seq_len(N_BOOT), function(b)
          var_responses(resample_states(estimation_sample), sanction, violence, controls) %>% mutate(draw = b)))
      ) %>%
        mutate(value = ifelse(shock == "violence", value * violence_shock, value)) %>%   # shock size, see header
        group_by(draw, identification, shock, response) %>%
        arrange(horizon, .by_group = TRUE) %>% mutate(cumulative = cumsum(value)) %>% ungroup()

      bands <- responses %>% filter(draw > 0) %>%
        group_by(identification, shock, response, horizon) %>%
        summarise(lower = quantile(value, 0.025), upper = quantile(value, 0.975),
                  cumulative_lower = quantile(cumulative, 0.025), cumulative_upper = quantile(cumulative, 0.975),
                  .groups = "drop")
      irf_rows[[paste(window_name, spec_name, control_set)]] <- responses %>% filter(draw == 0) %>% select(-draw) %>%
        left_join(bands, by = c("identification", "shock", "response", "horizon")) %>%
        mutate(window = window_name, window_label = WINDOWS[[window_name]]$label, specification = spec_name,
               control_set = control_set, violence_shock_size = violence_shock, bootstrap_draws = N_BOOT, .before = 1)
    }
  }
}
gdelt_irf <- bind_rows(irf_rows)
write_csv(gdelt_irf, file.path(TABLES, "gdelt_irf_results.csv"))

cumulative_plot <- gdelt_irf %>%
  filter(shock != response, identification == "simple") %>%
  mutate(panel = paste0(ifelse(shock == "sanction", "Violence after a new-sanction shock",
                               "New sanctions after a violence shock"), " (", specification, ")"),
         control_set = gsub("_", " ", control_set))
figure_cumulative <- ggplot(cumulative_plot, aes(horizon, cumulative, colour = window_label, fill = window_label)) +
  geom_hline(yintercept = 0, colour = "#52514e", linewidth = 0.3) +
  geom_ribbon(aes(ymin = cumulative_lower, ymax = cumulative_upper), alpha = 0.12, colour = NA) +
  geom_line(linewidth = 0.8) +
  facet_grid(control_set ~ panel, scales = "free_y") +
  scale_colour_manual(values = WINDOW_COLOURS) + scale_fill_manual(values = WINDOW_COLOURS) +
  scale_x_continuous(breaks = seq(0, IRF_HORIZON, 2)) +
  labs(title = "Cumulative impulse responses with GDELT violence (simple identification)",
       x = "Years after the shock", y = "Cumulative response",
       caption = paste0("As fig13, with GDELT instead of UCDP. Shocks: one new sanction / one new case; violence: one ",
                        "above-median year (incidence) or one within-state SD of the GDELT share (levels).\n",
                        "95% country-cluster bootstrap bands (", N_BOOT, " draws). VAR(", N_LAGS, "), state and year FE.")) +
  theme_paper() + theme(strip.text = element_text(size = 7.5))
save_figure(figure_cumulative, "fig14_gdelt_cumulative_irf.png", 12, 6.5)


# =============================================================================
# Part 7. Report
# =============================================================================
format_test <- function(chi2, p, sum_coef) sprintf("%.2f%s (p = %.3f), sum %.3f", chi2, significance_stars(p), p, sum_coef)
direction_label <- function(equation) ifelse(equation == "violence", "Sanctions → violence", "Violence → sanctions")

# --- Table 1 side by side with UCDP --------------------------------------------------
ucdp_granger <- read_csv(file.path(TABLES, "table1_granger.csv"), show_col_types = FALSE) %>%
  transmute(specification, control_set, estimator, equation,
            `UCDP, 1991–2019` = format_test(chi2, p_value, sum_cross_lags))
granger_comparison <- function(chosen_estimator) {
  gdelt_granger %>%
    filter(estimator == chosen_estimator) %>%
    mutate(cell = format_test(chi2, p_value, sum_cross_lags)) %>%
    select(specification, control_set, estimator, equation, sample_label, cell) %>%
    pivot_wider(names_from = sample_label, values_from = cell) %>%
    left_join(ucdp_granger, by = c("specification", "control_set", "estimator", "equation")) %>%
    mutate(direction = direction_label(equation)) %>%
    arrange(desc(equation), specification, control_set) %>%
    select(direction, specification, control_set, `UCDP, 1991–2019`, everything(), -estimator, -equation)
}

# --- lag grid: p-values, OLS --------------------------------------------------------
lag_grid_table <- function(chosen_window) {
  gdelt_lag_grid %>%
    filter(window == chosen_window, estimator == "OLS") %>%
    arrange(desc(equation), specification, control_set, other_lags, own_lags) %>%   # column order of Table 2
    mutate(column = paste0(direction_label(equation), ", ", specification, ", ", gsub("_", " ", control_set)),
           cell = sprintf("%.3f%s%s", p_value, significance_stars(p_value), ifelse(lowest_bic, " †", "")),
           lags = paste0("(", own_lags, ", ", other_lags, ")")) %>%
    select(lags, column, cell) %>%
    pivot_wider(names_from = column, values_from = cell)
}

# --- response functions and cumulative IRFs ---------------------------------------------
response_table <- gdelt_response_functions %>%
  filter(version == "two-way FE", horizon %in% c(-2, -1, 0, 1, 2, 3, 5)) %>%
  mutate(cell = sprintf("%.3f%s", estimate, significance_stars(p_value))) %>%
  select(window_label, label, horizon, cell) %>%
  pivot_wider(names_from = horizon, values_from = cell, names_prefix = "h = ") %>%
  arrange(label, window_label)

irf_table <- gdelt_irf %>%
  filter(shock != response, horizon == IRF_HORIZON) %>%
  mutate(direction = ifelse(shock == "sanction", "New sanction → violence", "Violence → new sanctions"),
         cell = sprintf("%.3f [%.3f, %.3f]%s", cumulative, cumulative_lower, cumulative_upper,
                        ifelse(cumulative_lower > 0 | cumulative_upper < 0, " *", ""))) %>%
  select(direction, specification, control_set, identification, window_label, cell) %>%
  pivot_wider(names_from = window_label, values_from = cell) %>%
  arrange(direction, specification, control_set, identification)
shock_sizes <- gdelt_irf %>% filter(specification == "levels") %>%
  distinct(window_label, control_set, violence_shock_size)

markdown <- c(
  "# GDELT robustness: the analysis with media-reported violence (plan R12)", "",
  paste0("Generated by `empirics/scripts/11_gdelt.R` on ", format(Sys.time(), "%Y-%m-%d %H:%M"), ". ",
         "Violence = GDELT assault + fight + mass-violence events per 1,000 GDELT events in the country-year. ",
         "Levels: `gdelt_lev` = that share in % of all events. Incidence: `gdelt_inc` = 1 if above the state's own ",
         "1979–2021 median (D6). Sanctions, controls, fixed effects, lags and estimators are as in scripts 04, 07 and 08. ",
         "Figures: `fig14_gdelt_cumulative_irf.png`, `fig15_gdelt_response_functions.png`."), "",
  "## 1. Sample and validation against UCDP", "",
  to_markdown(gdelt_sample),
  paste0("Validation, ", min(SAMPLE_YEARS), "–", max(SAMPLE_YEARS), " (state-years with both measures):"), "",
  to_markdown(gdelt_validation),
  "## 2. Stationarity and persistence", "",
  "Maddala–Wu and Choi combine state ADF tests (H0: unit root in every state); small p = stationary. ",
  "FE AR(1) with state and year effects, Nickell-corrected; within SD = standard deviation within states.", "",
  to_markdown(gdelt_stationarity %>% select(window, variable, version, states_tested, share_rejecting_5pct,
                                            maddala_wu_p, choi_z, choi_p)),
  to_markdown(gdelt_persistence),
  "## 3. Granger tests (Table 1 with GDELT), χ²(2) (p), sum of the other side's lag coefficients", "",
  "### A. OLS", "", to_markdown(granger_comparison("OLS")),
  "### B. Half-panel jackknife", "", to_markdown(granger_comparison("jackknife")),
  "Stability: largest roots of all GDELT VARs are in `gdelt_granger.csv` (column `largest_root`). ",
  paste0("Thin-coverage check: GDELT measures set to missing in state-years with fewer than ", THIN_COVERAGE_EVENTS,
         " reported events (shares of very few events are noisy)."), "",
  "## 4. Lag grid (Table 2 with GDELT): p-values of the Granger tests, OLS", "",
  "(own, other) lags; † = lowest BIC in the column. Jackknife version in `gdelt_lag_grid.csv`.", "",
  "### A. 1991–2019", "", to_markdown(lag_grid_table("ucdp_years")),
  "### B. 1981–2021", "", to_markdown(lag_grid_table("full_gdelt")),
  "## 5. Empirical response functions (JP Fig. 2), two-way FE version", "",
  "Difference in the mean outcome k years after an event year relative to other years, net of state and year means. ",
  "Raw version in `gdelt_response_functions.csv`; LP-DiD event study with GDELT in `12_lpdid.R` (extension).", "",
  to_markdown(response_table),
  "## 6. Cumulative impulse responses after 10 years (95% bootstrap interval; * = excludes 0)", "",
  to_markdown(irf_table),
  "Size of the violence shock in the levels specification (one within-state SD of `gdelt_lev`, percentage points):", "",
  to_markdown(shock_sizes, digits = 2),
  paste0("*Notes:* ", N_BOOT, " country-cluster bootstrap draws. * p<0.1, ** p<0.05, *** p<0.01; SE clustered by state. ",
         "UCDP column: script 04 (violence ≥ 25 deaths / log deaths per 100k). Units differ between UCDP and GDELT, ",
         "so compare signs and significance, not magnitudes.")
)
writeLines(markdown, file.path(TABLES, "gdelt_results.md"))

cat("\nGranger tests, OLS (GDELT vs UCDP):\n")
print(as.data.frame(granger_comparison("OLS")), row.names = FALSE)
cat("\nWrote", file.path(TABLES, "gdelt_results.md"), "\n")
