# =============================================================================
# 07_empirical_response.R — what happens after a new sanction / after a conflict?
# Model-free counterpart of the VAR: Jaeger & Paserman (2008), Figures 2A/2B.
# (empirics/ANALYSIS_PLAN.md, section 5)
#
# Two directions, each for the incidence and the levels version:
#   after a NEW SANCTION (event: new_sanction = 1) -> violence in t-3 ... t+8
#   after a CONFLICT     (event: conflict year)     -> new sanctions in t-3 ... t+8
#
# Empirical response functions: for each horizon k, the difference between the
# mean outcome k years after an event year and in all other years:
#     y_i,t+k = a_k + r_k * event_it + e
# Two versions:
#   raw         - plain means, as in JP
#   two-way FE  - outcome net of state and year means first; in a panel the raw
#                 version mixes "after an event" with "in a country that has events"
# Negative k (leads) show what happened BEFORE the event.
# JP scale their response "per fatality"; here the response is per event year.
# Standard errors clustered by state; 95% bands.
#
# The LP-DiD event study (Dube et al.) that used to be part B of this script is
# now in 12_lpdid.R: it is an extension, not part of the Jaeger & Paserman base case.
#
# Input : empirics/results/data/analysis_panel.csv
# Output: empirics/results/tables/response_functions.csv
#         empirics/results/tables/empirical_response.md
#         empirics/results/figures/fig10_response_functions.png
# =============================================================================

source(here::here("empirics", "scripts", "00_setup.R"))
source(here::here("empirics", "scripts", "functions.R"))

analysis <- read_csv(file.path(SAMPLE_DATA, "analysis_panel.csv"), show_col_types = FALSE)

LEADS   <- 3           # years shown before the event
HORIZON <- 8           # years shown after the event

# Event / outcome pairs. "event" must be a 0/1 variable.
RESPONSES <- list(
  list(name = "violence_after_sanction_incidence", event = "new_sanction", outcome = "viol_inc",
       label = "Conflict (0/1) after a new sanction"),
  list(name = "violence_after_sanction_levels",    event = "new_sanction", outcome = "viol_lev",
       label = "log(1 + deaths per 100k) after a new sanction"),
  list(name = "sanctions_after_conflict_incidence", event = "viol_inc",    outcome = "new_sanction",
       label = "New sanction (0/1) after a conflict"),
  list(name = "sanctions_after_conflict_levels",    event = "viol_inc",    outcome = "n_new_cases",
       label = "New sanction cases after a conflict")
)


# =============================================================================
# Helper functions
# =============================================================================

# Outcome net of state and year means (two-way within transformation, by
# regression so that it is exact in an unbalanced panel)
two_way_demean <- function(data, variable) {
  rows <- !is.na(data[[variable]])
  fit <- lm(reformulate(c("factor(gwcode)", "factor(yr)"), response = variable), data = data[rows, ])
  out <- rep(NA_real_, nrow(data))
  out[rows] <- residuals(fit)
  out
}

# Value of a variable k years later (k > 0) or earlier (k < 0) for the same state
value_at <- function(data, variable, k) lag_by_year(data, variable, -k)

# Regression coefficient of `term` with clustered SE, as a one-row table
clustered_estimate <- function(formula, data, term) {
  fit <- lm(formula, data = data)
  covariance <- sandwich::vcovCL(fit, cluster = data$gwcode, type = "HC1")
  estimate <- coef(fit)[[term]]; se <- sqrt(covariance[term, term])
  tibble(estimate = estimate, se = se, lower = estimate - 1.96 * se, upper = estimate + 1.96 * se,
         p_value = 2 * pnorm(-abs(estimate / se)), observations = nobs(fit),
         events = sum(data[[term]] == 1))
}


# =============================================================================
# Empirical response functions
# =============================================================================
response_rows <- list()
for (spec in RESPONSES) {
  data <- analysis
  data$outcome_fe <- two_way_demean(data, spec$outcome)
  for (k in -LEADS:HORIZON) {
    data$outcome_raw_k <- value_at(data, spec$outcome, k)
    data$outcome_fe_k  <- value_at(data, "outcome_fe", k)
    for (version in c("raw", "two-way FE")) {
      y <- if (version == "raw") "outcome_raw_k" else "outcome_fe_k"
      sample_k <- data %>% filter(in_window, !is.na(.data[[y]]), !is.na(.data[[spec$event]]))
      response_rows[[paste(spec$name, k, version)]] <-
        clustered_estimate(reformulate(spec$event, response = y), sample_k, spec$event) %>%
        mutate(response = spec$name, label = spec$label, version = version, horizon = k, .before = 1)
    }
  }
}
response_functions <- bind_rows(response_rows)
write_csv(response_functions, file.path(TABLES, "response_functions.csv"))


# =============================================================================
# Figure
# =============================================================================
label_order <- sapply(RESPONSES, `[[`, "label")

figure_response <- ggplot(response_functions %>% mutate(label = factor(label, levels = label_order)),
                          aes(horizon, estimate, colour = version, fill = version)) +
  geom_hline(yintercept = 0, colour = "#52514e", linewidth = 0.3) +
  geom_vline(xintercept = 0, colour = "#8a8984", linewidth = 0.3, linetype = "dashed") +
  geom_ribbon(aes(ymin = lower, ymax = upper), alpha = 0.15, colour = NA) +
  geom_line(linewidth = 0.8) + geom_point(size = 1.2) +
  facet_wrap(~ label, scales = "free_y") +
  scale_colour_manual(values = c(raw = PAPER_COLOURS[["grey"]], `two-way FE` = PAPER_COLOURS[["blue"]])) +
  scale_fill_manual(values = c(raw = PAPER_COLOURS[["grey"]], `two-way FE` = PAPER_COLOURS[["blue"]])) +
  scale_x_continuous(breaks = -LEADS:HORIZON) +
  labs(title = "Empirical response functions: outcome k years after an event year, relative to other years",
       x = "Years after the event (0 = event year)", y = "Difference in mean outcome",
       caption = paste0("Event = new sanction (top) or conflict year (bottom). Raw: plain means (Jaeger & Paserman Fig. 2); ",
                        "two-way FE: outcome net of state and year means.\n95% bands, SE clustered by state. ",
                        min(SAMPLE_YEARS), "-", max(SAMPLE_YEARS), ".")) +
  theme_paper()
save_figure(figure_response, "fig10_response_functions.png", 10, 6.5)


# =============================================================================
# Markdown summary: selected horizons
# =============================================================================
format_cell <- function(estimate, p) sprintf("%.3f%s", estimate, significance_stars(p))
summary_table <- function(results, horizons) {
  results %>% filter(horizon %in% horizons) %>%
    mutate(cell = format_cell(estimate, p_value)) %>%
    select(label, horizon, cell) %>%
    pivot_wider(names_from = horizon, values_from = cell, names_prefix = "h = ")
}
to_markdown <- function(table) {
  c(paste0("| ", paste(names(table), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(table)), collapse = "|"), "|"),
    apply(table, 1, function(row) paste0("| ", paste(ifelse(is.na(row), "", row), collapse = " | "), " |")), "")
}
SHOWN_HORIZONS <- c(-2, -1, 0, 1, 2, 3, 5)

markdown <- c(
  "# Empirical response functions (Jaeger & Paserman 2008, Fig. 2)", "",
  paste0("Generated by `empirics/scripts/07_empirical_response.R` on ", format(Sys.time(), "%Y-%m-%d %H:%M"),
         ". Figure: `fig10_response_functions.png`."), "",
  "Difference in the mean outcome k years after an event year, relative to all other years.", "",
  "## A. Two-way FE version (outcome net of state and year means)", "",
  to_markdown(summary_table(response_functions %>% filter(version == "two-way FE"), SHOWN_HORIZONS)),
  "## B. Raw version (plain means, as in Jaeger & Paserman)", "",
  to_markdown(summary_table(response_functions %>% filter(version == "raw"), SHOWN_HORIZONS)),
  "*Notes:* * p<0.1, ** p<0.05, *** p<0.01; SE clustered by state. Negative horizons are years before the event. ",
  "The raw version also reflects permanent differences between states (states with many events have higher ",
  "outcomes in every year); the two-way FE version removes them."
)
writeLines(markdown, file.path(TABLES, "empirical_response.md"))

cat("\nResponse functions, two-way FE (selected horizons):\n")
print(as.data.frame(summary_table(response_functions %>% filter(version == "two-way FE"), SHOWN_HORIZONS)),
      row.names = FALSE)
cat("\nWrote", file.path(TABLES, "empirical_response.md"), "\n")
