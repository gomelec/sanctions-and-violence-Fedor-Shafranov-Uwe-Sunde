# =============================================================================
# 12_lpdid.R — EXTENSION (not part of the Jaeger & Paserman base case):
# local-projection difference-in-differences event study, LP-DiD
# (Dube, Girardi, Jorda & Taylor 2023/2025). Status: not yet confirmed as part of
# the project; kept separate so the base case (scripts 04, 07, 08) stays pure JP.
#
# Question: how does the outcome evolve after an event, compared with similar
# state-years without one?
#     y_i,t+h - y_i,t-1 = beta_h * event_it + gamma_h' (y_i,t-1, y_i,t-2) + year FE_t + e
# estimated only on
#   treated       : event in t and no event in the previous CLEAN_WINDOW years
#   clean controls: no event in t and in the previous CLEAN_WINDOW years
# so that units still reacting to an earlier event never serve as controls (the
# "negative weighting" problem of two-way FE; de Chaisemartin & D'Haultfoeuille).
# Lagged outcomes control for selection on past outcomes (sanctions follow
# violence), as in Dube et al.'s democracy application.
# Pre-event horizons (h <= -2) are estimated WITHOUT the lagged-outcome controls:
# y(t+h) - y(t-1) would otherwise be a function of the controls themselves (h = -2
# exactly), so the "pre-trend" would be zero by construction.
# For the violence -> sanctions direction the event is a violence ONSET (violence
# after CLEAN_WINDOW calm years), because violence is highly persistent.
#
# Two data sets:
#   UCDP  (main measures; sample of 01, years 1989-2019)
#   GDELT (robustness R12; panel written by 11_gdelt.R, both GDELT windows) — skipped
#         if 11_gdelt.R has not been run
#
# Input : empirics/results/data/analysis_panel.csv        (01)
#         empirics/results/data/gdelt_analysis_panel.csv  (11, optional)
# Output: empirics/results/tables/lpdid_event_study.csv, gdelt_lpdid_event_study.csv, lpdid.md
#         empirics/results/figures/fig11_lpdid_event_study.png
#         empirics/results/figures/fig16_gdelt_lpdid_event_study.png
# =============================================================================

source(here::here("empirics", "scripts", "00_setup.R"))
source(here::here("empirics", "scripts", "functions.R"))

LEADS        <- 3           # years shown before the event
HORIZON      <- 8           # years shown after the event
CLEAN_WINDOW <- 3           # years without an event required before t (treated and controls)

UCDP_RESPONSES <- list(
  list(name = "violence_after_sanction_incidence", event = "new_sanction", outcome = "viol_inc",
       label = "Conflict (0/1) after a new sanction"),
  list(name = "violence_after_sanction_levels",    event = "new_sanction", outcome = "viol_lev",
       label = "log(1 + deaths per 100k) after a new sanction"),
  list(name = "sanctions_after_conflict_incidence", event = "viol_inc",    outcome = "new_sanction",
       label = "New sanction (0/1) after a conflict onset"),
  list(name = "sanctions_after_conflict_levels",    event = "viol_inc",    outcome = "n_new_cases",
       label = "New sanction cases after a conflict onset")
)
GDELT_RESPONSES <- list(
  list(name = "violence_after_sanction_incidence", event = "new_sanction", outcome = "gdelt_inc",
       label = "GDELT violence above median (0/1) after a new sanction"),
  list(name = "violence_after_sanction_levels",    event = "new_sanction", outcome = "gdelt_lev",
       label = "GDELT violent events (%) after a new sanction"),
  list(name = "sanctions_after_violence_incidence", event = "gdelt_inc",   outcome = "new_sanction",
       label = "New sanction (0/1) after GDELT violence onset"),
  list(name = "sanctions_after_violence_levels",    event = "gdelt_inc",   outcome = "n_new_cases",
       label = "New sanction cases after GDELT violence onset")
)
GDELT_WINDOWS <- list(       # same windows as 11_gdelt.R
  "GDELT, 1991-2019 (years of Table 1)" = (min(SAMPLE_YEARS) + VAR_LAGS):max(SAMPLE_YEARS),
  "GDELT, 1981-2021 (full period)"      = (1979 + VAR_LAGS):2021
)


# =============================================================================
# Helper functions
# =============================================================================

value_at <- function(data, variable, k) lag_by_year(data, variable, -k)   # k > 0: future value

# Regression coefficient of `term` with clustered SE, as a one-row table
clustered_estimate <- function(formula, data, term) {
  fit <- lm(formula, data = data)
  covariance <- sandwich::vcovCL(fit, cluster = data$gwcode, type = "HC1")
  estimate <- coef(fit)[[term]]; se <- sqrt(covariance[term, term])
  tibble(estimate = estimate, se = se, lower = estimate - 1.96 * se, upper = estimate + 1.96 * se,
         p_value = 2 * pnorm(-abs(estimate / se)), observations = nobs(fit),
         events = sum(data[[term]] == 1))
}

# LP-DiD estimates for horizons -LEADS..HORIZON of one event/outcome pair.
# `data` needs gwcode, yr, in_window, the event and the outcome.
lpdid_event_study <- function(data, spec) {
  data <- data %>% arrange(gwcode, yr)
  past_events <- Reduce(`+`, lapply(seq_len(CLEAN_WINDOW), function(j) lag_by_year(data, spec$event, j)))
  data <- data %>%
    mutate(past_events   = past_events,
           treated       = as.integer(.data[[spec$event]] == 1 & past_events == 0),   # new event after a quiet spell
           clean_control = .data[[spec$event]] == 0 & past_events == 0,
           outcome_lag1  = lag_by_year(data, spec$outcome, 1),
           outcome_lag2  = lag_by_year(data, spec$outcome, 2))

  rows <- list()
  for (h in -LEADS:HORIZON) {
    if (h == -1) {                                    # reference year: y(t-1) - y(t-1) = 0 by construction
      rows[[as.character(h)]] <- tibble(horizon = -1, estimate = 0, se = 0, lower = 0, upper = 0, p_value = NA)
      next
    }
    data$change_h <- value_at(data, spec$outcome, h) - data$outcome_lag1
    sample_h <- data %>%
      filter(in_window, treated == 1 | clean_control,
             !is.na(change_h), !is.na(outcome_lag1), !is.na(outcome_lag2))
    regression <- if (h >= 0) change_h ~ treated + outcome_lag1 + outcome_lag2 + factor(yr)
                  else        change_h ~ treated + factor(yr)          # pre-trend test, see header
    rows[[as.character(h)]] <- clustered_estimate(regression, sample_h, "treated") %>% mutate(horizon = h, .before = 1)
  }
  bind_rows(rows) %>% mutate(response = spec$name, label = spec$label, .before = 1) %>% arrange(horizon)
}

# Event-study figure; `colour_by` = column that distinguishes lines (or NULL)
event_study_figure <- function(results, label_order, title, caption, colour_by = NULL) {
  results <- results %>% mutate(label = factor(label, levels = label_order))
  aesthetics <- if (is.null(colour_by)) aes(horizon, estimate)
                else aes(horizon, estimate, colour = .data[[colour_by]], fill = .data[[colour_by]])
  colours <- c(PAPER_COLOURS[["orange"]], PAPER_COLOURS[["blue"]])
  figure <- ggplot(results, aesthetics) +
    geom_hline(yintercept = 0, colour = "#52514e", linewidth = 0.3) +
    geom_vline(xintercept = -0.5, colour = "#8a8984", linewidth = 0.3, linetype = "dashed")
  if (is.null(colour_by)) {
    figure <- figure +
      geom_ribbon(aes(ymin = lower, ymax = upper), fill = colours[1], alpha = 0.18) +
      geom_line(colour = colours[1], linewidth = 0.8) + geom_point(colour = colours[1], size = 1.2)
  } else {
    figure <- figure +
      geom_ribbon(aes(ymin = lower, ymax = upper), alpha = 0.12, colour = NA) +
      geom_line(linewidth = 0.8) + geom_point(size = 1.1) +
      scale_colour_manual(values = colours) + scale_fill_manual(values = colours)
  }
  figure +
    facet_wrap(~ label, scales = "free_y") +
    scale_x_continuous(breaks = -LEADS:HORIZON) +
    labs(title = title, x = "Years relative to the event (reference year: -1)", y = "Effect on y(t+h) - y(t-1)",
         caption = caption) +
    theme_paper()
}

caption_text <- paste0("Dube et al. LP-DiD: treated = event after ", CLEAN_WINDOW, " event-free years (violence: onset); ",
                       "clean controls = no event in t and the ", CLEAN_WINDOW, " years before.\nYear FE and two lags of the ",
                       "outcome as controls after the event (pre-event years without them). 95% bands, SE clustered by state.")

format_cell <- function(estimate, p) sprintf("%.3f%s", estimate, significance_stars(p))
summary_table <- function(results, horizons, extra_columns = character(0)) {
  results %>% filter(horizon %in% horizons) %>%
    mutate(cell = format_cell(estimate, p_value)) %>%
    select(all_of(extra_columns), label, horizon, cell) %>%
    pivot_wider(names_from = horizon, values_from = cell, names_prefix = "h = ")
}
to_markdown <- function(table) {
  c(paste0("| ", paste(names(table), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(table)), collapse = "|"), "|"),
    apply(table, 1, function(row) paste0("| ", paste(ifelse(is.na(row), "", row), collapse = " | "), " |")), "")
}
SHOWN_HORIZONS <- c(-3, -2, 0, 1, 2, 3, 5)


# =============================================================================
# 1. UCDP
# =============================================================================
analysis <- read_csv(file.path(SAMPLE_DATA, "analysis_panel.csv"), show_col_types = FALSE)
lpdid <- bind_rows(lapply(UCDP_RESPONSES, function(spec) lpdid_event_study(analysis, spec)))
write_csv(lpdid, file.path(TABLES, "lpdid_event_study.csv"))
save_figure(event_study_figure(lpdid, sapply(UCDP_RESPONSES, `[[`, "label"),
                               "LP-DiD event study: change in the outcome relative to the year before the event",
                               caption_text),
            "fig11_lpdid_event_study.png", 10, 6.5)

markdown <- c(
  "# LP-DiD event study — extension, not part of the Jaeger & Paserman base case", "",
  paste0("Generated by `empirics/scripts/12_lpdid.R` on ", format(Sys.time(), "%Y-%m-%d %H:%M"),
         ". Figures: `fig11_lpdid_event_study.png`, `fig16_gdelt_lpdid_event_study.png`."), "",
  "## A. UCDP (change in outcome since t−1, treated vs clean controls)", "",
  to_markdown(summary_table(lpdid, SHOWN_HORIZONS)),
  "Treated events (h = 0):", "",
  to_markdown(lpdid %>% filter(horizon == 0) %>% select(label, treated_events = events, observations))
)


# =============================================================================
# 2. GDELT (only if 11_gdelt.R has written its panel)
# =============================================================================
gdelt_file <- file.path(SAMPLE_DATA, "gdelt_analysis_panel.csv")
if (file.exists(gdelt_file)) {
  gdelt_panel <- read_csv(gdelt_file, show_col_types = FALSE)
  gdelt_rows <- list()
  for (window_label in names(GDELT_WINDOWS)) {
    data <- gdelt_panel %>% mutate(in_window = yr %in% GDELT_WINDOWS[[window_label]])
    # sample rule of 01 / 11: at least MIN_OBS complete years of the main variables in the window
    kept_states <- data %>% filter(in_window) %>% group_by(gwcode) %>%
      summarise(complete = sum(complete.cases(new_sanction, n_new_cases, gdelt_inc, gdelt_lev)), .groups = "drop") %>%
      filter(complete >= MIN_OBS) %>% pull(gwcode)
    data <- data %>% filter(gwcode %in% kept_states)
    for (spec in GDELT_RESPONSES) {
      gdelt_rows[[paste(window_label, spec$name)]] <-
        lpdid_event_study(data, spec) %>% mutate(window_label = window_label, .before = 1)
    }
  }
  gdelt_lpdid <- bind_rows(gdelt_rows)
  write_csv(gdelt_lpdid, file.path(TABLES, "gdelt_lpdid_event_study.csv"))
  save_figure(event_study_figure(gdelt_lpdid, sapply(GDELT_RESPONSES, `[[`, "label"),
                                 "LP-DiD event study with GDELT violence",
                                 paste0("As fig11, with GDELT instead of UCDP (violence onset: above-median GDELT violence after ",
                                        CLEAN_WINDOW, " years at or below the median).\n", caption_text),
                                 colour_by = "window_label"),
              "fig16_gdelt_lpdid_event_study.png", 10, 6.5)
  markdown <- c(markdown,
    "## B. GDELT", "",
    to_markdown(summary_table(gdelt_lpdid, SHOWN_HORIZONS, "window_label") %>% arrange(label, window_label)),
    "Treated events (h = 0):", "",
    to_markdown(gdelt_lpdid %>% filter(horizon == 0) %>% select(window_label, label, treated_events = events)))
} else {
  cat("\nNo GDELT panel found (run 11_gdelt.R first): GDELT part skipped.\n")
  markdown <- c(markdown, "## B. GDELT", "", "Not run: `11_gdelt.R` has not written `gdelt_analysis_panel.csv` yet.", "")
}

markdown <- c(markdown,
  "*Notes:* * p<0.1, ** p<0.05, *** p<0.01; SE clustered by state. Negative horizons are pre-event years: ",
  "estimates far from zero there indicate that the event was preceded by different trends (selection), ",
  "which the lagged outcomes in LP-DiD partly control for. With annual data the h = 0 effect includes ",
  "escalation within the event year that may have triggered the event.")
writeLines(markdown, file.path(TABLES, "lpdid.md"))

cat("\nLP-DiD, UCDP (selected horizons):\n")
print(as.data.frame(summary_table(lpdid, SHOWN_HORIZONS)), row.names = FALSE)
cat("\nWrote", file.path(TABLES, "lpdid.md"), "\n")
