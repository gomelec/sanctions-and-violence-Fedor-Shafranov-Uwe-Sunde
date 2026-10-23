


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
