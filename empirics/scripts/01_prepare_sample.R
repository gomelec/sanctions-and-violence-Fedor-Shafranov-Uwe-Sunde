# =============================================================================
# 01_prepare_sample.R — analysis variables and estimation sample
# (empirics/ANALYSIS_PLAN.md, sections 2 and 3)
#
# Input : data/processed/sanctions_violence/sanctions_violence_panel.csv
# Output: empirics/results/data/analysis_panel.csv       kept states; years SAMPLE_YEARS plus
#                                                          MAX_LAGS earlier years (needed for lags)
#         empirics/results/tables/sample_exclusions.csv  every dropped state and why
#         empirics/results/tables/sample_coverage.csv    per state: years, complete years, kept?
#         empirics/results/tables/sample_summary.csv     mean / sd / n of the main variables
#
# Sample rule (plan 3 and 6a): keep every state with at least MIN_OBS complete
# years of the four main variables inside SAMPLE_YEARS. There is NO variance
# filter: states that never have violence or never get a new sanction stay in,
# because their zeros are informative (dropping them would select on the outcome).
# =============================================================================

source(here::here("empirics", "scripts", "00_setup.R"))
source(here::here("empirics", "scripts", "functions.R"))

panel <- read_panel()
first_year_kept <- min(SAMPLE_YEARS) - MAX_LAGS     # earlier years are kept only to build lags


# --- 1. Analysis variables -------------------------------------------------------------
analysis <- panel %>%
  filter(yr >= first_year_kept, yr <= max(SAMPLE_YEARS)) %>%
  transmute(
    gwcode, gw_name, iso3c, yr,

    # Sanctions: GSDB flow variables (data/README.md, S11)
    new_sanction,                      # 1 if at least one case begins against the state in t
    n_new_cases,                       # number of cases beginning in t
    lifted_sanction,                   # 1 if at least one case ended (used later, R11)
    n_cases_received,                  # stock: cases in force in t (only used as a control)

    # Violence: UCDP organized violence, best estimate (missing before 1989)
    deaths    = cumulative_total_deaths_in_orgvio_best,
    deaths_pc = cumulative_total_deaths_in_orgvio_best_pc,          # per 100,000 inhabitants
    viol_inc  = as.integer(deaths >= CONFLICT_MIN_DEATHS),          # incidence: conflict year (0/1)
    viol_lev  = log1p(deaths_pc),                                   # levels: log(1 + deaths per 100,000)

    # Inputs for the controls
    gdp = gdp_ext,
    v2x_polyarchy,
    ex_yugo_1991_2016
  ) %>%
  arrange(gwcode, yr)

# Controls, all lagged one year so that they are predetermined (plan, section 2)
analysis$gdp_growth      <- log(analysis$gdp) - log(lag_by_year(analysis, "gdp", 1))
analysis$ctrl_stock      <- lag_by_year(analysis, "n_cases_received", 1)   # sanction cases in force in t-1
analysis$ctrl_gdp_growth <- lag_by_year(analysis, "gdp_growth", 1)         # GDP per capita growth in t-1
analysis$ctrl_democracy  <- lag_by_year(analysis, "v2x_polyarchy", 1)      # V-Dem polyarchy in t-1

analysis$in_window <- analysis$yr %in% SAMPLE_YEARS     # TRUE = year of the estimation window

MAIN_VARIABLES <- c("new_sanction", "n_new_cases", "viol_inc", "viol_lev")


# --- 2. Coverage per state and exclusions ----------------------------------------------
coverage <- analysis %>%
  filter(in_window) %>%
  group_by(gwcode, gw_name) %>%
  summarise(
    years_in_window             = n(),
    complete_years_main         = sum(complete.cases(across(all_of(MAIN_VARIABLES)))),
    complete_years_with_controls = sum(complete.cases(across(all_of(c(MAIN_VARIABLES, CONTROLS))))),
    ever_conflict               = any(viol_inc == 1, na.rm = TRUE),
    ever_new_sanction           = any(new_sanction == 1, na.rm = TRUE),
    .groups = "drop"
  )

too_short <- coverage %>%
  filter(complete_years_main < MIN_OBS) %>%
  transmute(gwcode, gw_name,
            reason = paste0("fewer than ", MIN_OBS, " complete years (", complete_years_main, ")"))

manually_excluded <- coverage %>%
  filter(gw_name %in% MANUAL_EXCLUDE$gw_name) %>%
  left_join(MANUAL_EXCLUDE, by = "gw_name") %>%
  transmute(gwcode, gw_name, reason)

exclusions  <- bind_rows(too_short, manually_excluded) %>% distinct(gwcode, .keep_all = TRUE)
kept_states <- setdiff(coverage$gwcode, exclusions$gwcode)
analysis_kept <- analysis %>% filter(gwcode %in% kept_states)


# --- 3. Write the files ------------------------------------------------------------------
write_csv(analysis_kept, file.path(SAMPLE_DATA, "analysis_panel.csv"))
write_csv(exclusions,    file.path(TABLES, "sample_exclusions.csv"))
write_csv(coverage %>% mutate(kept = gwcode %in% kept_states),
          file.path(TABLES, "sample_coverage.csv"))

window_rows <- analysis_kept %>% filter(in_window)
summary_table <- window_rows %>%
  summarise(across(c(new_sanction, n_new_cases, viol_inc, viol_lev, deaths_pc,
                     ctrl_stock, ctrl_gdp_growth, ctrl_democracy),
                   list(mean = ~ mean(.x, na.rm = TRUE),
                        sd   = ~ sd(.x, na.rm = TRUE),
                        n    = ~ sum(!is.na(.x))))) %>%
  pivot_longer(everything(), names_to = c("variable", ".value"),
               names_pattern = "(.*)_(mean|sd|n)$")
write_csv(summary_table, file.path(TABLES, "sample_summary.csv"))


# --- 4. Log --------------------------------------------------------------------------------
cat("\nSample window:", min(SAMPLE_YEARS), "-", max(SAMPLE_YEARS),
    "| earlier years kept for lags from", first_year_kept, "\n")
cat("States in window:", nrow(coverage), "| kept:", length(kept_states),
    "| excluded:", nrow(exclusions), "\n")
if (nrow(exclusions) > 0) print(as.data.frame(exclusions), row.names = FALSE)

cat("\nKept states: state-years in window", nrow(window_rows),
    "| complete main variables", sum(complete.cases(window_rows[, MAIN_VARIABLES])),
    "| complete incl. controls", sum(complete.cases(window_rows[, c(MAIN_VARIABLES, CONTROLS)])), "\n")

kept_coverage <- coverage %>% filter(gwcode %in% kept_states)
cat("Kept states never in conflict (>= ", CONFLICT_MIN_DEATHS, " deaths) in the window: ",
    sum(!kept_coverage$ever_conflict), " | never a new sanction: ",
    sum(!kept_coverage$ever_new_sanction), "  (kept on purpose, plan 6a)\n", sep = "")

missing_controls <- window_rows %>%
  filter(complete.cases(across(all_of(MAIN_VARIABLES))),
         !complete.cases(across(all_of(CONTROLS)))) %>%
  count(gw_name, sort = TRUE)
cat("\nState-years with the main variables but missing controls",
    "(dropped only in specifications with controls):", sum(missing_controls$n), "\n")
print(head(as.data.frame(missing_controls), 15), row.names = FALSE)

cat("\nMeans in the window:\n")
print(as.data.frame(summary_table), row.names = FALSE, digits = 3)
cat("\nWrote", file.path(SAMPLE_DATA, "analysis_panel.csv"), "\n")
