# =============================================================================
# 09_robustness.R — robustness checks of the reaction functions (Table 1)
# (empirics/ANALYSIS_PLAN.md, section 7)
#
# Part 1 (R3): nonlinear models — Jaeger & Paserman (2008), footnote 3 (probit /
# zero-inflated Poisson). Our main models are linear: linear probability models
# for incidence and OLS on log(1 + deaths per 100,000) for levels. Two concerns:
#   - incidence: a linear probability model with many zeros can predict outside [0, 1];
#   - levels: log(1 + y) with many zeros has no percentage interpretation and its
#     coefficients depend on the units of y (Chen & Roth 2024).
# Checks, same regressors, fixed effects, samples and clustering as Table 1:
#   Logit (incidence)  P(y_it = 1) = Lambda(own lags + other lags + X + state FE + year FE)
#                      y = conflict (0/1) in the violence equation, new sanction (0/1) in
#                      the sender equation
#   PPML (levels)      E[y_it] = exp(own lags + other lags + X + state FE + year FE)
#                      (Poisson pseudo-maximum likelihood; Santos Silva & Tenreyro 2006)
#                      y = deaths per 100,000 UNTRANSFORMED in the violence equation (also
#                      winsorised at the 99th percentile: Rwanda 1994 alone would otherwise
#                      dominate), number of new cases in the sender equation. The right-hand
#                      side is the same as in the levels VAR (lags of log deaths and of new cases).
# Fixed effects enter as dummies (the same estimates as fixest::feglm / fepois).
# States whose outcome never varies in the sample (e.g. never in conflict) carry no
# information in a fixed-effects logit / Poisson model (their state effect is -Inf)
# and are dropped; the number of dropped states is reported. Fixed-effects logit has
# an incidental-parameter bias of order 1/T, like the Nickell bias of OLS.
#
# Reported per equation: Granger Wald chi2 for the two lags of the other variable
# (clustered by state) and the sum of the two lag coefficients. Comparable scales:
#   logit: sum x mean of p(1 - p) = approximate average partial effect on the
#          probability, directly comparable to the OLS (linear probability) sum
#   PPML : sum = semi-elasticity: exp(sum) - 1 = proportional change of the outcome
#
# Part 2 (R10): raw deaths instead of log deaths in the LINEAR levels VAR, as in
# Jaeger & Paserman, who use raw fatality counts. The violence variable of the
# levels VAR -- both as outcome and as lagged regressor -- is deaths per 100,000:
#   raw         untransformed (Rwanda 1994 = 12,577 per 100,000)
#   winsorised  capped at the 99th percentile (main version of the check) and at the
#               95th percentile (stronger cap) of all state-years 1989-2019
# Same sample, lags, controls, fixed effects, clustering as Table 1; FE-OLS and
# half-panel jackknife; Granger tests, sums of the cross lags, largest root.
#
# Part 3 (R10, dynamics): impulse responses and response functions of the levels VAR
# with deaths per 100,000 capped at the 99th percentile -- the magnitudes in deaths
# rather than log points (as JP's Section V numbers, which come from raw counts).
#   - cumulative impulse responses, three identifications, country-cluster bootstrap
#     (IRF_BOOT_DRAWS, default 199, as in 08); shocks: one new case / +1 death per 100k
#   - empirical response functions (JP Fig. 2, raw and two-way FE): capped deaths
#     around a new-sanction year (the other direction does not involve deaths)
# Uncapped deaths are not used for dynamics: Rwanda 1994 alone sets the persistence.
#
# Part 4 (decision D8): same-sample control check -- all control versions (FE only, each control
# alone, stock in t-1 vs t-3, all controls) on one common sample; FE only on the full sample as reference.
#
# Part 5 (R9): Yugoslavia attribution -- Table 1 without the ex-Yugoslav states, and with the
# ex-Yugoslav states as one cluster.
#
# Further parts (leave-one-country-out, Driscoll-Kraay, splits, ...) will follow.
#
# Input : empirics/results/data/analysis_panel.csv, empirics/results/tables/table1_granger.csv
# Output: empirics/results/tables/robustness_nonlinear.csv, robustness_nonlinear.md   (Part 1)
#         empirics/results/tables/robustness_raw_deaths.csv, robustness_raw_deaths.md (Part 2)
#         empirics/results/tables/robustness_capped_irf.csv, robustness_capped_response.csv,
#         robustness_capped_dynamics.md                                              (Part 3)
#         empirics/results/figures/fig17_capped_deaths_dynamics.png                   (Part 3)
#         empirics/results/tables/robustness_controls.csv, robustness_controls.md     (Part 4)
#         empirics/results/tables/robustness_yugoslavia.csv, robustness_yugoslavia.md (Part 5)
# Runtime: Parts 1-2 under a minute; Part 3 about 1.5 seconds per bootstrap draw; Parts 4-5 about 20 seconds.
# =============================================================================

source(here::here("empirics", "scripts", "00_setup.R"))
source(here::here("empirics", "scripts", "functions.R"))

analysis <- read_csv(file.path(SAMPLE_DATA, "analysis_panel.csv"), show_col_types = FALSE)
N_LAGS <- VAR_LAGS
CONTROL_SETS <- list(with_controls = CONTROLS, no_controls = character(0))
WINSOR_QUANTILE <- 0.99


# =============================================================================
# Helper functions
# =============================================================================

# Fit one nonlinear reaction function and test the lags of the other variable.
#   data      estimation sample (Table 1 sample of the specification)
#   outcome   dependent variable of the nonlinear model
#   own       variable whose lags are the "own" lags (the VAR variable of this equation)
#   other     variable whose lags are tested (Granger block)
#   family    binomial(link = "logit") or quasipoisson()
fit_nonlinear <- function(data, outcome, own, other, controls, family) {
  # drop states whose outcome is constant (logit) or always zero (Poisson): no information
  informative <- data %>%
    group_by(gwcode) %>%
    summarise(varies = if (family$family == "binomial") n_distinct(.data[[outcome]]) > 1
                       else any(.data[[outcome]] > 0), .groups = "drop") %>%
    filter(varies) %>% pull(gwcode)
  used <- data %>% filter(gwcode %in% informative)

  regressors <- c(lag_names(own, N_LAGS), lag_names(other, N_LAGS), controls, "factor(gwcode)", "factor(yr)")
  model <- suppressWarnings(glm(reformulate(regressors, response = outcome), family = family, data = used,
                                control = glm.control(maxit = 100)))
  covariance <- sandwich::vcovCL(model, cluster = used$gwcode, type = "HC0")

  tested <- lag_names(other, N_LAGS)
  b <- coef(model)[tested]
  V <- covariance[tested, tested]
  chi2 <- as.numeric(t(b) %*% solve(V, b))
  fitted_values <- fitted(model)
  scale <- if (family$family == "binomial") mean(fitted_values * (1 - fitted_values)) else NA

  tibble(chi2 = chi2, df = length(tested), p_value = pchisq(chi2, length(tested), lower.tail = FALSE),
         sum_cross_lags = sum(b), sum_cross_se = sqrt(sum(V)),
         lag1 = b[[1]], lag2 = b[[2]],
         average_partial_effect_sum = sum(b) * scale,
         converged = model$converged,
         n_obs = nrow(used), n_states = length(informative),
         states_dropped = n_distinct(data$gwcode) - length(informative))
}


# =============================================================================
# Part 1. Logit and PPML versions of Table 1
# =============================================================================
MODELS <- list(
  # name, specification of the Table 1 sample, equation, outcome, own VAR variable, other variable, family
  list(model = "Logit",            specification = "incidence", equation = "violence",
       outcome = "viol_inc",     own = "viol_inc",     other = "new_sanction", family = binomial()),
  list(model = "Logit",            specification = "incidence", equation = "sender",
       outcome = "new_sanction", own = "new_sanction", other = "viol_inc",     family = binomial()),
  list(model = "PPML",             specification = "levels",    equation = "violence",
       outcome = "deaths_pc",    own = "viol_lev",     other = "n_new_cases",  family = quasipoisson()),
  list(model = "PPML, winsorised", specification = "levels",    equation = "violence",
       outcome = "deaths_pc_winsorised", own = "viol_lev", other = "n_new_cases", family = quasipoisson()),
  list(model = "PPML",             specification = "levels",    equation = "sender",
       outcome = "n_new_cases",  own = "n_new_cases",  other = "viol_lev",     family = quasipoisson())
)
SAMPLE_VARIABLES <- list(incidence = c(sanction = "new_sanction", violence = "viol_inc"),
                         levels    = c(sanction = "n_new_cases",  violence = "viol_lev"))

# Winsorised deaths per 100,000 (cap at the 99th percentile of the estimation window)
cap <- quantile(analysis$deaths_pc[analysis$in_window], WINSOR_QUANTILE, na.rm = TRUE)
analysis$deaths_pc_winsorised <- pmin(analysis$deaths_pc, cap)
cat("Winsorising deaths per 100,000 at", round(cap, 2), "(", WINSOR_QUANTILE * 100, "th percentile )\n")

result_rows <- list()
for (spec in MODELS) {
  for (control_set in names(CONTROL_SETS)) {
    controls <- CONTROL_SETS[[control_set]]
    variables <- SAMPLE_VARIABLES[[spec$specification]]
    # the Table 1 estimation sample of this VAR, with the nonlinear outcome available
    estimation_sample <- build_estimation_sample(analysis, variables[["sanction"]], variables[["violence"]],
                                                 N_LAGS, controls) %>%
      filter(!is.na(.data[[spec$outcome]]))
    result_rows[[paste(spec$model, spec$equation, control_set)]] <- bind_cols(
      tibble(model = spec$model, specification = spec$specification, equation = spec$equation,
             control_set = control_set, outcome = spec$outcome, tested = spec$other),
      fit_nonlinear(estimation_sample, spec$outcome, spec$own, spec$other, controls, spec$family))
    cat("Done:", spec$model, spec$equation, control_set, "\n")
  }
}
nonlinear <- bind_rows(result_rows)
write_csv(nonlinear, file.path(TABLES, "robustness_nonlinear.csv"))


# =============================================================================
# Report: side by side with the OLS results of Table 1
# =============================================================================
ols <- read_csv(file.path(TABLES, "table1_granger.csv"), show_col_types = FALSE) %>%
  filter(estimator == "OLS") %>%
  transmute(specification, equation, control_set,
            ols = sprintf("%.2f%s (p = %.3f), sum %.3f", chi2, significance_stars(p_value), p_value, sum_cross_lags))

comparison <- nonlinear %>%
  mutate(direction = ifelse(equation == "violence", "Sanctions → violence", "Violence → sanctions"),
         nonlinear_test = sprintf("%.2f%s (p = %.3f)", chi2, significance_stars(p_value), p_value),
         lag_coefficients = sprintf("%.3f / %.3f", lag1, lag2),
         comparable_sum = ifelse(model == "Logit",
                                 sprintf("APE %.3f", average_partial_effect_sum),
                                 sprintf("%.3f (%+.1f%%)", sum_cross_lags, 100 * (exp(sum_cross_lags) - 1))),
         sample = sprintf("%d / %d (−%d)", n_obs, n_states, states_dropped)) %>%
  left_join(ols, by = c("specification", "equation", "control_set")) %>%
  select(direction, model, control_set, `OLS (Table 1)` = ols, `nonlinear: χ²(2)` = nonlinear_test,
         `lag t−1 / t−2` = lag_coefficients, `sum (comparable scale)` = comparable_sum,
         `obs / states (dropped)` = sample) %>%
  arrange(direction, model, control_set)

to_markdown <- function(table) {
  c(paste0("| ", paste(names(table), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(table)), collapse = "|"), "|"),
    apply(table, 1, function(row) paste0("| ", paste(ifelse(is.na(row), "", row), collapse = " | "), " |")), "")
}
markdown <- c(
  "# Robustness R3: logit and PPML versions of the reaction functions", "",
  paste0("Generated by `empirics/scripts/09_robustness.R` on ", format(Sys.time(), "%Y-%m-%d %H:%M"), "."), "",
  "Same samples, lags (2), controls, state and year fixed effects and clustering as Table 1. ",
  "Logit: incidence equations (conflict 0/1, new sanction 0/1). PPML: levels equations with untransformed outcomes ",
  paste0("(deaths per 100,000; also winsorised at the ", WINSOR_QUANTILE * 100, "th percentile = ", round(cap, 1),
         "; number of new cases), right-hand side as in the levels VAR. "),
  "States whose outcome never varies are dropped (no information with fixed effects).", "",
  to_markdown(comparison),
  "*Notes:* χ²(2): Wald test that both lags of the other variable are zero, clustered by state. ",
  "Lag coefficients in log-odds (logit) or log points (PPML). APE = sum of the two logit lag coefficients × mean ",
  "p(1−p): approximate average partial effect on the probability, comparable to the OLS sum. PPML: sum and implied ",
  "proportional change exp(sum) − 1 of the outcome per unit of the lagged variable. * p<0.1, ** p<0.05, *** p<0.01."
)
writeLines(markdown, file.path(TABLES, "robustness_nonlinear.md"))

cat("\nNonlinear robustness (R3):\n")
print(as.data.frame(comparison), row.names = FALSE)
cat("\nWrote", file.path(TABLES, "robustness_nonlinear.md"), "\n")



# =============================================================================
# Part 2 (R10). Linear levels VAR with raw deaths per 100,000
# =============================================================================
DEATH_VERSIONS <- list(
  raw            = list(cap_quantile = NA,   label = "Raw deaths per 100k"),
  winsorised_p99 = list(cap_quantile = 0.99, label = "Deaths per 100k, capped at p99"),
  winsorised_p95 = list(cap_quantile = 0.95, label = "Deaths per 100k, capped at p95")
)

raw_rows <- list(); caps <- list()
for (version in names(DEATH_VERSIONS)) {
  cap_quantile <- DEATH_VERSIONS[[version]]$cap_quantile
  data <- analysis
  if (is.na(cap_quantile)) {
    data$deaths_level <- data$deaths_pc
    caps[[version]] <- NA
  } else {
    cap <- quantile(data$deaths_pc[data$in_window], cap_quantile, na.rm = TRUE)
    data$deaths_level <- pmin(data$deaths_pc, cap)        # cap applied to all years, also those used as lags
    caps[[version]] <- cap
  }

  for (control_set in names(CONTROL_SETS)) {
    controls <- CONTROL_SETS[[control_set]]
    # same state-years as Table 1 (levels): require the log version too, then swap in the raw version
    estimation_sample <- build_estimation_sample(data, "n_new_cases", "viol_lev", N_LAGS, controls) %>%
      select(-starts_with("deaths_level")) %>%
      left_join(add_lags(data, "deaths_level", N_LAGS) %>%
                  select(gwcode, yr, starts_with("deaths_level")), by = c("gwcode", "yr"))

    equations <- list(violence = list(outcome = "deaths_level", other = "n_new_cases"),
                      sender   = list(outcome = "n_new_cases",  other = "deaths_level"))
    estimates <- lapply(equations, function(eq) list(
      OLS       = fit_reaction_function(estimation_sample, eq$outcome, eq$other, N_LAGS, controls),
      jackknife = half_panel_jackknife(estimation_sample, eq$outcome, eq$other, N_LAGS, controls)))

    for (estimator in c("OLS", "jackknife")) {
      root <- largest_var_root(coef(estimates$violence[[estimator]]), coef(estimates$sender[[estimator]]),
                               "deaths_level", "n_new_cases", N_LAGS)
      for (equation_name in names(equations)) {
        model <- estimates[[equation_name]][[estimator]]
        other <- equations[[equation_name]]$other
        test  <- wald_test(model, lag_names(other, N_LAGS))
        lags  <- coef(model)[lag_names(other, N_LAGS)]
        raw_rows[[paste(version, control_set, estimator, equation_name)]] <- tibble(
          version = version, label = DEATH_VERSIONS[[version]]$label, cap = caps[[version]],
          control_set = control_set, estimator = estimator, equation = equation_name,
          chi2 = test$chi2, df = test$df, p_value = test$p_value,
          lag1 = lags[[1]], lag2 = lags[[2]], sum_cross_lags = test$sum_coef, sum_cross_se = test$sum_se,
          mean_deaths = mean(estimation_sample$deaths_level), sd_deaths = sd(estimation_sample$deaths_level),
          n_obs = nobs(estimates[[equation_name]]$OLS), n_states = n_distinct(estimation_sample$gwcode),
          largest_root = root)
      }
    }
    cat("Done: raw deaths,", version, control_set, "\n")
  }
}
raw_deaths <- bind_rows(raw_rows)
write_csv(raw_deaths, file.path(TABLES, "robustness_raw_deaths.csv"))

# --- report ------------------------------------------------------------------------
ols_levels <- read_csv(file.path(TABLES, "table1_granger.csv"), show_col_types = FALSE) %>%
  filter(specification == "levels") %>%
  transmute(control_set, estimator, equation,
            `log deaths (Table 1)` = sprintf("%.2f%s (p = %.3f), sum %.3f", chi2, significance_stars(p_value),
                                             p_value, sum_cross_lags))
raw_table <- raw_deaths %>%
  mutate(direction = ifelse(equation == "violence", "Sanctions → violence", "Violence → sanctions"),
         cell = sprintf("%.2f%s (p = %.3f), sum %.4f", chi2, significance_stars(p_value), p_value, sum_cross_lags)) %>%
  select(direction, control_set, estimator, equation, label, cell) %>%
  pivot_wider(names_from = label, values_from = cell) %>%
  left_join(ols_levels, by = c("control_set", "estimator", "equation")) %>%
  select(direction, control_set, estimator, `log deaths (Table 1)`, everything(), -equation) %>%
  arrange(direction, estimator, control_set)
roots <- raw_deaths %>% filter(equation == "violence") %>%
  select(label, control_set, estimator, largest_root, mean_deaths, sd_deaths, n_obs, n_states)

markdown <- c(
  "# Robustness R10: raw deaths instead of log deaths in the levels VAR", "",
  paste0("Generated by `empirics/scripts/09_robustness.R` on ", format(Sys.time(), "%Y-%m-%d %H:%M"), "."), "",
  "Linear levels VAR(2) as in Table 1 (FE-OLS and half-panel jackknife, state and year FE, clustered by state), ",
  "with deaths per 100,000 instead of log(1 + deaths per 100,000) as the violence variable (outcome and lags). ",
  paste0("Caps: p99 = ", round(caps$winsorised_p99, 2), ", p95 = ", round(caps$winsorised_p95, 2),
         " deaths per 100,000 (all state-years 1989–2019)."), "",
  "Granger χ²(2) and sum of the two cross-lag coefficients (sanctions → violence: deaths per 100,000 per new case; ",
  "violence → sanctions: new cases per death per 100,000).", "",
  to_markdown(raw_table),
  "Stability and scale of the violence variable:", "",
  to_markdown(roots %>% mutate(across(where(is.numeric), ~ round(.x, 3)))),
  "*Notes:* * p<0.1, ** p<0.05, *** p<0.01."
)
writeLines(markdown, file.path(TABLES, "robustness_raw_deaths.md"))

cat("\nRaw deaths (R10):\n")
print(as.data.frame(raw_table), row.names = FALSE)
cat("\nWrote", file.path(TABLES, "robustness_raw_deaths.md"), "\n")



# =============================================================================
# Part 3 (R10, dynamics). Capped deaths: impulse responses and response functions
# =============================================================================
IRF_HORIZON <- 10
N_BOOT      <- as.integer(Sys.getenv("IRF_BOOT_DRAWS", "199"))
LEADS <- 3; HORIZON <- 8

capped_data <- analysis
cap_p99 <- quantile(capped_data$deaths_pc[capped_data$in_window], 0.99, na.rm = TRUE)
capped_data$deaths_capped <- pmin(capped_data$deaths_pc, cap_p99)

# Responses of one VAR for the three identification schemes (as var_responses() in 08)
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

# --- 3a. cumulative impulse responses ----------------------------------------------------
irf_rows <- list()
for (control_set in names(CONTROL_SETS)) {
  controls <- CONTROL_SETS[[control_set]]
  # Table 1 levels sample, with capped deaths as the violence variable
  estimation_sample <- build_estimation_sample(capped_data, "n_new_cases", "viol_lev", N_LAGS, controls) %>%
    select(-starts_with("deaths_capped")) %>%
    left_join(add_lags(capped_data, "deaths_capped", N_LAGS) %>% select(gwcode, yr, starts_with("deaths_capped")),
              by = c("gwcode", "yr"))
  cat("Capped-deaths IRF |", control_set, "|", nrow(estimation_sample), "obs |", N_BOOT, "draws\n")

  set.seed(20261022)
  responses <- bind_rows(
    var_responses(estimation_sample, "n_new_cases", "deaths_capped", controls) %>% mutate(draw = 0),
    bind_rows(lapply(seq_len(N_BOOT), function(b)
      var_responses(resample_states(estimation_sample), "n_new_cases", "deaths_capped", controls) %>% mutate(draw = b)))
  ) %>%
    group_by(draw, identification, shock, response) %>%
    arrange(horizon, .by_group = TRUE) %>% mutate(cumulative = cumsum(value)) %>% ungroup()

  bands <- responses %>% filter(draw > 0) %>%
    group_by(identification, shock, response, horizon) %>%
    summarise(lower = quantile(value, 0.025), upper = quantile(value, 0.975),
              cumulative_lower = quantile(cumulative, 0.025), cumulative_upper = quantile(cumulative, 0.975),
              .groups = "drop")
  irf_rows[[control_set]] <- responses %>% filter(draw == 0) %>% select(-draw) %>%
    left_join(bands, by = c("identification", "shock", "response", "horizon")) %>%
    mutate(control_set = control_set, cap = cap_p99, bootstrap_draws = N_BOOT, .before = 1)
}
capped_irf <- bind_rows(irf_rows)
write_csv(capped_irf, file.path(TABLES, "robustness_capped_irf.csv"))

# --- 3b. response functions: capped deaths around a new-sanction year ------------------
two_way_demean <- function(data, variable) {
  rows <- !is.na(data[[variable]])
  fit <- lm(reformulate(c("factor(gwcode)", "factor(yr)"), response = variable), data = data[rows, ])
  out <- rep(NA_real_, nrow(data)); out[rows] <- residuals(fit); out
}
response_data <- capped_data
response_data$deaths_capped_fe <- two_way_demean(response_data, "deaths_capped")
response_rows <- list()
for (k in -LEADS:HORIZON) {
  for (version in c("raw", "two-way FE")) {
    variable <- if (version == "raw") "deaths_capped" else "deaths_capped_fe"
    response_data$outcome_k <- lag_by_year(response_data, variable, -k)     # value k years later
    sample_k <- response_data %>% filter(in_window, !is.na(outcome_k), !is.na(new_sanction))
    fit <- lm(outcome_k ~ new_sanction, data = sample_k)
    se  <- sqrt(sandwich::vcovCL(fit, cluster = sample_k$gwcode, type = "HC1")["new_sanction", "new_sanction"])
    estimate <- coef(fit)[["new_sanction"]]
    response_rows[[paste(k, version)]] <- tibble(version = version, horizon = k, estimate = estimate, se = se,
                                                 lower = estimate - 1.96 * se, upper = estimate + 1.96 * se,
                                                 p_value = 2 * pnorm(-abs(estimate / se)))
  }
}
capped_response <- bind_rows(response_rows)
write_csv(capped_response, file.path(TABLES, "robustness_capped_response.csv"))

# --- figure: cumulative IRFs (no same-year effect) and response function -----------------
irf_plot <- capped_irf %>%
  filter(shock != response, identification == "simple") %>%
  mutate(panel = ifelse(shock == "sanction", "Cumulative IRF: deaths per 100k after one new case",
                        "Cumulative IRF: new cases after +1 death per 100k"),
         control_set = gsub("_", " ", control_set)) %>%
  transmute(panel, line = control_set, horizon, estimate = cumulative, lower = cumulative_lower, upper = cumulative_upper)
response_plot <- capped_response %>%
  transmute(panel = "Response function: deaths per 100k around a new-sanction year",
            line = version, horizon, estimate, lower, upper)
figure_data <- bind_rows(irf_plot, response_plot) %>%
  mutate(panel = factor(panel, levels = c("Cumulative IRF: deaths per 100k after one new case",
                                          "Cumulative IRF: new cases after +1 death per 100k",
                                          "Response function: deaths per 100k around a new-sanction year")))
LINE_COLOURS <- c(`no controls` = PAPER_COLOURS[["blue"]], `with controls` = PAPER_COLOURS[["orange"]],
                  raw = PAPER_COLOURS[["grey"]], `two-way FE` = PAPER_COLOURS[["aqua"]])
figure <- ggplot(figure_data, aes(horizon, estimate, colour = line, fill = line)) +
  geom_hline(yintercept = 0, colour = "#52514e", linewidth = 0.3) +
  geom_ribbon(aes(ymin = lower, ymax = upper), alpha = 0.12, colour = NA) +
  geom_line(linewidth = 0.8) +
  facet_wrap(~ panel, scales = "free", ncol = 3) +
  scale_colour_manual(values = LINE_COLOURS) + scale_fill_manual(values = LINE_COLOURS) +
  scale_x_continuous(breaks = seq(-LEADS, IRF_HORIZON, 1), minor_breaks = NULL,
                     labels = function(x) ifelse(x %% 2 == 0, x, "")) +
  labs(title = paste0("Levels VAR with deaths per 100,000 capped at the 99th percentile (", round(cap_p99, 1), ")"),
       x = "Years after the shock / event", y = NULL,
       caption = paste0("IRFs: no same-year effect (Jaeger & Paserman fn. 12), cumulative over years 0..h, 95% country-cluster ",
                        "bootstrap bands (", N_BOOT, " draws). Response function: difference in mean capped deaths k years\n",
                        "after a new-sanction year relative to other years (raw; two-way FE = net of state and year means), ",
                        "SE clustered by state. ", min(SAMPLE_YEARS), "-", max(SAMPLE_YEARS), ".")) +
  theme_paper() + theme(strip.text = element_text(size = 8))
save_figure(figure, "fig17_capped_deaths_dynamics.png", 12, 4.4)

# --- report ------------------------------------------------------------------------------
irf_table <- capped_irf %>%
  filter(shock != response, horizon %in% c(2, 5, 10)) %>%
  mutate(direction = ifelse(shock == "sanction", "New case → deaths per 100k", "+1 death per 100k → new cases"),
         cell = sprintf("%.3f [%.3f, %.3f]%s", cumulative, cumulative_lower, cumulative_upper,
                        ifelse(cumulative_lower > 0 | cumulative_upper < 0, " *", ""))) %>%
  select(direction, control_set, identification, horizon, cell) %>%
  pivot_wider(names_from = horizon, values_from = cell, names_prefix = "cumulative, h = ") %>%
  arrange(direction, control_set, identification)
response_table <- capped_response %>%
  filter(horizon %in% c(-2, -1, 0, 1, 2, 3, 5)) %>%
  mutate(cell = sprintf("%.3f%s", estimate, significance_stars(p_value))) %>%
  select(version, horizon, cell) %>%
  pivot_wider(names_from = horizon, values_from = cell, names_prefix = "h = ")

writeLines(c(
  "# Robustness R10 (dynamics): levels VAR with capped deaths per 100,000", "",
  paste0("Generated by `empirics/scripts/09_robustness.R` on ", format(Sys.time(), "%Y-%m-%d %H:%M"),
         ". Deaths per 100,000 capped at the 99th percentile (", round(cap_p99, 2), "). Figure: ",
         "`fig17_capped_deaths_dynamics.png`."), "",
  "## Cumulative impulse responses (95% bootstrap interval; * = excludes zero)", "",
  paste0("Shocks: one new sanction case; +1 death per 100,000. ", N_BOOT, " country-cluster bootstrap draws."), "",
  to_markdown(irf_table),
  "## Response function: capped deaths per 100,000 around a new-sanction year", "",
  to_markdown(response_table),
  "*Notes:* * p<0.1, ** p<0.05, *** p<0.01; SE clustered by state."
), file.path(TABLES, "robustness_capped_dynamics.md"))

cat("\nCapped deaths, cumulative IRFs:\n"); print(as.data.frame(irf_table), row.names = FALSE)
cat("\nWrote", file.path(TABLES, "robustness_capped_dynamics.md"), "\n")



# =============================================================================
# Part 4 (decision D8). Same-sample control check
#   Question: do the Table 1 results change because of the controls themselves or
#   because the controls sample (174 states, V-Dem missing for microstates) differs
#   from the no-controls sample (197 states)? And which control matters?
#   All versions are estimated on ONE common sample: the state-years with every
#   control available, including the sanction stock lagged three years.
#   Versions (both equations, incidence and levels, FE-OLS, SE clustered by state):
#     FE only                  no controls (state and year FE only)
#     stock t-1 / t-3          sanction cases in force in t-1 (as in CONTROLS) or t-3.
#                              The stock in t-1 contains the new cases of t-1 and t-2,
#                              i.e. the tested sanction lags themselves
#                              (K_t-1 = K_t-3 + new_t-1 + new_t-2 + joined - lifted);
#                              the stock in t-3 is dated before both lags.
#     GDP growth, democracy    one control at a time
#     all controls             CONTROLS (the Table 1 "with controls" set)
#     all, stock t-3           CONTROLS with the stock in t-3 instead of t-1
#   Plus, for reference, FE only on the full no-controls sample (197 states).
# =============================================================================
analysis$ctrl_stock_t3 <- lag_by_year(analysis, "n_cases_received", 3)   # sanction cases in force in t-3

CONTROL_VERSIONS <- list(
  "FE only"            = character(0),
  "stock t-1"          = "ctrl_stock",
  "stock t-3"          = "ctrl_stock_t3",
  "GDP growth"         = "ctrl_gdp_growth",
  "democracy"          = "ctrl_democracy",
  "all controls"       = CONTROLS,
  "all, stock t-3"     = c(setdiff(CONTROLS, "ctrl_stock"), "ctrl_stock_t3")
)
ALL_CONTROL_COLUMNS <- unique(unlist(CONTROL_VERSIONS))
SPECIFICATIONS <- list(incidence = c(sanction = "new_sanction", violence = "viol_inc"),
                       levels    = c(sanction = "n_new_cases",  violence = "viol_lev"))

# Granger tests of both equations of one VAR (OLS); one row per equation
granger_both_equations <- function(data, sanction, violence, controls, cluster = data$gwcode) {
  equations <- list(violence = c(outcome = violence, other = sanction),
                    sender   = c(outcome = sanction, other = violence))
  bind_rows(lapply(names(equations), function(equation_name) {
    outcome <- equations[[equation_name]][["outcome"]]
    other   <- equations[[equation_name]][["other"]]
    model <- fit_reaction_function(data, outcome, other, N_LAGS, controls, cluster_se = FALSE)
    model$vcov_clustered <- sandwich::vcovCL(model, cluster = cluster, type = "HC1")
    test <- wald_test(model, lag_names(other, N_LAGS))
    lags <- coef(model)[lag_names(other, N_LAGS)]
    tibble(equation = equation_name, chi2 = test$chi2, p_value = test$p_value,
           lag1 = lags[[1]], lag2 = lags[[2]], sum_cross_lags = test$sum_coef, sum_cross_se = test$sum_se,
           n_obs = nobs(model), n_states = n_distinct(data$gwcode))
  }))
}

control_rows <- list()
for (spec_name in names(SPECIFICATIONS)) {
  sanction <- SPECIFICATIONS[[spec_name]][["sanction"]]
  violence <- SPECIFICATIONS[[spec_name]][["violence"]]
  # common sample: every control (incl. the stock in t-3) available
  common_sample <- build_estimation_sample(analysis, sanction, violence, N_LAGS, ALL_CONTROL_COLUMNS)
  for (version in names(CONTROL_VERSIONS)) {
    control_rows[[paste(spec_name, version)]] <-
      granger_both_equations(common_sample, sanction, violence, CONTROL_VERSIONS[[version]]) %>%
      mutate(specification = spec_name, sample = "common controls sample", version = version, .before = 1)
  }
  # reference: FE only on the full no-controls sample (Table 1, panel B)
  full_sample <- build_estimation_sample(analysis, sanction, violence, N_LAGS)
  control_rows[[paste(spec_name, "full")]] <-
    granger_both_equations(full_sample, sanction, violence, character(0)) %>%
    mutate(specification = spec_name, sample = "full sample (Table 1 B)", version = "FE only", .before = 1)
}
control_check <- bind_rows(control_rows)
write_csv(control_check, file.path(TABLES, "robustness_controls.csv"))

control_table <- control_check %>%
  mutate(direction = ifelse(equation == "violence", "Sanctions → violence", "Violence → sanctions"),
         row_label = ifelse(sample == "common controls sample", version, "FE only, full sample (reference)"),
         cell = sprintf("%.2f%s (p = %.3f); %.3f / %.3f; sum %.3f (%.3f)", chi2, significance_stars(p_value),
                        p_value, lag1, lag2, sum_cross_lags, sum_cross_se)) %>%
  select(direction, specification, row_label, cell) %>%
  pivot_wider(names_from = specification, values_from = cell) %>%
  arrange(direction)
sample_sizes <- control_check %>% distinct(specification, sample, n_obs, n_states)

writeLines(c(
  "# Robustness (decision D8): same-sample control check", "",
  paste0("Generated by `empirics/scripts/09_robustness.R` (part 4) on ", format(Sys.time(), "%Y-%m-%d %H:%M"), "."), "",
  "FE-OLS VAR(2) as in Table 1, all versions on one common sample (all controls available, incl. the sanction ",
  "stock in t−3). Cell: Granger χ²(2) (p); lag t−1 / lag t−2 coefficient of the other variable; sum (SE). ",
  "SE clustered by state. Last row per direction: FE only on the full no-controls sample, for reference.", "",
  to_markdown(control_table),
  "Samples:", "", to_markdown(sample_sizes),
  "*Notes:* stock t−1 = sanction cases in force in t−1 (contains the new cases of t−1 and t−2); stock t−3 = in force ",
  "in t−3 (dated before both tested lags). * p<0.1, ** p<0.05, *** p<0.01."
), file.path(TABLES, "robustness_controls.md"))
cat("\nSame-sample control check (D8):\n"); print(as.data.frame(control_table), row.names = FALSE)
cat("\nWrote", file.path(TABLES, "robustness_controls.md"), "\n")



# =============================================================================
# Part 5 (R9). Yugoslavia attribution
#   GSDB cases against "Yugoslavia" are attributed to the successor republics
#   (data/README_yugoslavia.md), so one sanction can appear as a new case in several
#   states in the same year. The ex_yugo_1991_2016 dummy (removed from CONTROLS on
#   2026-10-23) cannot handle this: with state FE it only contrasts 2017-19 with
#   earlier years. Two checks instead, Table 1 specification (OLS, with and without
#   CONTROLS), both specifications:
#     main                    all states, SE clustered by state (= Table 1)
#     without ex-Yugoslavia   the successor states of Yugoslavia dropped entirely
#                             (all states with ex_yugo_1991_2016 = 1 in any year)
#     ex-Yugoslavia one cluster  all states, but the successor states form ONE cluster
#                             (their duplicated cases are not independent observations)
# =============================================================================
ex_yugoslav_states <- analysis %>% filter(ex_yugo_1991_2016 == 1) %>% distinct(gwcode, gw_name)
cat("\nEx-Yugoslav states:", paste(ex_yugoslav_states$gw_name, collapse = ", "), "\n")

yugoslavia_rows <- list()
for (spec_name in names(SPECIFICATIONS)) {
  sanction <- SPECIFICATIONS[[spec_name]][["sanction"]]
  violence <- SPECIFICATIONS[[spec_name]][["violence"]]
  for (control_set in names(CONTROL_SETS)) {
    controls <- CONTROL_SETS[[control_set]]
    estimation_sample <- build_estimation_sample(analysis, sanction, violence, N_LAGS, controls)
    one_yugoslav_cluster <- ifelse(estimation_sample$gwcode %in% ex_yugoslav_states$gwcode, -1L,
                                   estimation_sample$gwcode)
    without_yugoslavia <- estimation_sample %>% filter(!gwcode %in% ex_yugoslav_states$gwcode)
    versions <- list(
      "main"                       = granger_both_equations(estimation_sample, sanction, violence, controls),
      "without ex-Yugoslavia"      = granger_both_equations(without_yugoslavia, sanction, violence, controls),
      "ex-Yugoslavia one cluster"  = granger_both_equations(estimation_sample, sanction, violence, controls,
                                                            cluster = one_yugoslav_cluster)
    )
    for (version in names(versions)) {
      yugoslavia_rows[[paste(spec_name, control_set, version)]] <- versions[[version]] %>%
        mutate(specification = spec_name, control_set = control_set, version = version, .before = 1)
    }
  }
}
yugoslavia_check <- bind_rows(yugoslavia_rows)
write_csv(yugoslavia_check, file.path(TABLES, "robustness_yugoslavia.csv"))

yugoslavia_table <- yugoslavia_check %>%
  mutate(direction = ifelse(equation == "violence", "Sanctions → violence", "Violence → sanctions"),
         cell = sprintf("%.2f%s (p = %.3f), sum %.3f (%.3f)", chi2, significance_stars(p_value), p_value,
                        sum_cross_lags, sum_cross_se)) %>%
  select(direction, control_set, version, specification, cell) %>%
  pivot_wider(names_from = specification, values_from = cell) %>%
  arrange(direction, control_set)

writeLines(c(
  "# Robustness R9: Yugoslavia attribution", "",
  paste0("Generated by `empirics/scripts/09_robustness.R` (part 5) on ", format(Sys.time(), "%Y-%m-%d %H:%M"), "."), "",
  paste0("Ex-Yugoslav states: ", paste(ex_yugoslav_states$gw_name, collapse = ", "), "."), "",
  "FE-OLS VAR(2) as in Table 1. *main* = Table 1; *without ex-Yugoslavia* = these states dropped; ",
  "*ex-Yugoslavia one cluster* = all states, standard errors clustered by state except that the ex-Yugoslav states ",
  "form one cluster. Cell: Granger χ²(2) (p), sum of the two cross-lag coefficients (SE).", "",
  to_markdown(yugoslavia_table),
  "*Notes:* * p<0.1, ** p<0.05, *** p<0.01."
), file.path(TABLES, "robustness_yugoslavia.md"))
cat("\nYugoslavia check (R9):\n"); print(as.data.frame(yugoslavia_table), row.names = FALSE)
cat("\nWrote", file.path(TABLES, "robustness_yugoslavia.md"), "\n")
