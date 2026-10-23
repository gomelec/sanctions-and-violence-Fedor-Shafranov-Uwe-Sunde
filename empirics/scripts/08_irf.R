# =============================================================================
# 08_irf.R — impulse responses of the panel VAR (Jaeger & Paserman 2008, Section V)
# (empirics/ANALYSIS_PLAN.md, section 4.3)
#
# An impulse response is the path of one variable over the next IRF_HORIZON years
# after a one-time shock to the other variable, with all later shocks set to zero.
# It is computed by iterating the two estimated equations forward, so it includes
# the feedback between violence and sanctions and each variable's own persistence
# (functions.R: var_ma_coefficients, impulse_responses).
#
# Shock size: one unit of the shocked variable.
#   incidence: one new sanction (0 -> 1); one conflict year (0 -> 1)
#   levels   : one additional new sanction case; +1 in log(1 + deaths per 100,000)
#
# Identification of same-year effects (annual data!):
#   simple                  Jaeger & Paserman fn. 12: no same-year effect on the other variable
#   cholesky_sanction_first a new sanction may affect violence in the same year, not vice versa
#   cholesky_violence_first violence may affect new sanctions in the same year, not vice versa
#   (the Cholesky responses are rescaled to a one-unit own shock, comparable to "simple")
#
# Uncertainty: country-cluster bootstrap. States are drawn with replacement
# (a state drawn twice enters twice with separate fixed effects), the two
# equations are re-estimated, the responses recomputed; 95% bands = 2.5th and
# 97.5th percentiles over N_BOOT draws. Also: the cumulative response (sum over
# horizons 0..h), Jaeger & Paserman's long-run number, and the point estimate
# from the half-panel-jackknife coefficients (bias-corrected).
#
# Input : empirics/results/data/analysis_panel.csv
# Output: empirics/results/tables/irf_results.csv, irf_summary.md
#         empirics/results/figures/fig12_irf_<control set>.png, fig13_cumulative_irf.png
# Runtime: about 3 seconds per bootstrap draw for all four models, i.e. about
#   10 minutes with the default 199 draws. For the final paper version use 999
#   (IRF_BOOT_DRAWS=999, about 45 minutes); for a quick test e.g. IRF_BOOT_DRAWS=20.
# =============================================================================

source(here::here("empirics", "scripts", "00_setup.R"))
source(here::here("empirics", "scripts", "functions.R"))

analysis <- read_csv(file.path(SAMPLE_DATA, "analysis_panel.csv"), show_col_types = FALSE)

N_LAGS      <- VAR_LAGS
IRF_HORIZON <- 10
N_BOOT      <- as.integer(Sys.getenv("IRF_BOOT_DRAWS", "199"))

SPECIFICATIONS <- list(
  incidence = list(sanction = "new_sanction", violence = "viol_inc"),
  levels    = list(sanction = "n_new_cases",  violence = "viol_lev")
)
CONTROL_SETS <- list(no_controls = character(0), with_controls = CONTROLS)


# =============================================================================
# Helper: all impulse responses of one estimated VAR
# =============================================================================

# Fits the two equations on `data` and returns the responses for the three
# identification schemes (long table). `jackknife = TRUE` uses the bias-corrected
# coefficients instead (point estimate only; Sigma from the OLS residuals).
var_responses <- function(data, sanction, violence, controls, jackknife = FALSE) {
  if (jackknife) {
    coef_violence <- coef(half_panel_jackknife(data, violence, sanction, N_LAGS, controls))
    coef_sender   <- coef(half_panel_jackknife(data, sanction, violence, N_LAGS, controls))
  }
  violence_model <- fit_reaction_function(data, violence, sanction, N_LAGS, controls, cluster_se = FALSE)
  sender_model   <- fit_reaction_function(data, sanction, violence, N_LAGS, controls, cluster_se = FALSE)
  if (!jackknife) {
    coef_violence <- coef(violence_model)
    coef_sender   <- coef(sender_model)
  }
  # residual covariance of the two equations (order: violence, sanction)
  residual_matrix <- cbind(residuals(violence_model), residuals(sender_model))
  Sigma <- crossprod(residual_matrix) / nrow(residual_matrix)

  Phi <- var_ma_coefficients(coef_violence, coef_sender, violence, sanction, N_LAGS, IRF_HORIZON)
  impacts <- impact_matrices(Sigma)
  bind_rows(lapply(names(impacts), function(identification)
    impulse_responses(Phi, impacts[[identification]]) %>% mutate(identification = identification)))
}

# Bootstrap sample: states drawn with replacement, each draw gets its own id
resample_states <- function(data) {
  states <- unique(data$gwcode)
  drawn  <- sample(states, length(states), replace = TRUE)
  bind_rows(lapply(seq_along(drawn), function(i) {
    data[data$gwcode == drawn[i], ] %>% mutate(original_gwcode = gwcode, gwcode = i)
  }))
}


# =============================================================================
# 1. Point estimates and bootstrap for every specification
# =============================================================================
all_results <- list()
for (spec_name in names(SPECIFICATIONS)) {
  sanction <- SPECIFICATIONS[[spec_name]]$sanction
  violence <- SPECIFICATIONS[[spec_name]]$violence

  for (control_set in names(CONTROL_SETS)) {
    controls <- CONTROL_SETS[[control_set]]
    estimation_sample <- build_estimation_sample(analysis, sanction, violence, N_LAGS, controls)
    cat("\n", spec_name, control_set, ":", nrow(estimation_sample), "observations,",
        n_distinct(estimation_sample$gwcode), "states,", N_BOOT, "bootstrap draws\n")

    point     <- var_responses(estimation_sample, sanction, violence, controls)
    jackknife <- var_responses(estimation_sample, sanction, violence, controls, jackknife = TRUE) %>%
      rename(jackknife = value)

    set.seed(20261021)
    draws <- bind_rows(lapply(seq_len(N_BOOT), function(b) {
      var_responses(resample_states(estimation_sample), sanction, violence, controls) %>% mutate(draw = b)
    }))

    # cumulative responses: running sum over horizons, for the point estimate and each draw
    point <- point %>% group_by(identification, shock, response) %>%
      arrange(horizon, .by_group = TRUE) %>% mutate(cumulative = cumsum(value)) %>% ungroup()
    draws <- draws %>% group_by(draw, identification, shock, response) %>%
      arrange(horizon, .by_group = TRUE) %>% mutate(cumulative = cumsum(value)) %>% ungroup()

    bands <- draws %>%
      group_by(identification, shock, response, horizon) %>%
      summarise(lower = quantile(value, 0.025), upper = quantile(value, 0.975),
                cumulative_lower = quantile(cumulative, 0.025), cumulative_upper = quantile(cumulative, 0.975),
                .groups = "drop")

    all_results[[paste(spec_name, control_set)]] <- point %>%
      left_join(bands, by = c("identification", "shock", "response", "horizon")) %>%
      left_join(jackknife %>% select(identification, shock, response, horizon, jackknife),
                by = c("identification", "shock", "response", "horizon")) %>%
      mutate(specification = spec_name, control_set = control_set, bootstrap_draws = N_BOOT, .before = 1)
  }
}
irf_results <- bind_rows(all_results)
write_csv(irf_results, file.path(TABLES, "irf_results.csv"))


# =============================================================================
# 2. Figures: the two cross responses (the Granger-relevant ones)
# =============================================================================
cross_responses <- irf_results %>%
  filter(shock != response) %>%
  mutate(panel = paste0(ifelse(shock == "sanction", "Violence after a new-sanction shock",
                               "New sanctions after a violence shock"),
                        " (", specification, ")"),
         panel = factor(panel, levels = c("Violence after a new-sanction shock (incidence)",
                                          "New sanctions after a violence shock (incidence)",
                                          "Violence after a new-sanction shock (levels)",
                                          "New sanctions after a violence shock (levels)")),
         identification = recode(identification,
                                 simple = "Simple (no same-year effect)",
                                 cholesky_sanction_first = "Cholesky, sanctions first",
                                 cholesky_violence_first = "Cholesky, violence first"))

IDENTIFICATION_COLOURS <- c("Simple (no same-year effect)" = PAPER_COLOURS[["blue"]],
                            "Cholesky, sanctions first"    = PAPER_COLOURS[["orange"]],
                            "Cholesky, violence first"     = PAPER_COLOURS[["aqua"]])

for (control_set in names(CONTROL_SETS)) {
  plot_data <- cross_responses %>% filter(control_set == !!control_set)
  simple <- plot_data %>% filter(identification == "Simple (no same-year effect)")
  figure <- ggplot(plot_data, aes(horizon, value, colour = identification)) +
    geom_hline(yintercept = 0, colour = "#52514e", linewidth = 0.3) +
    geom_ribbon(data = simple, aes(ymin = lower, ymax = upper), fill = PAPER_COLOURS[["blue"]],
                alpha = 0.15, colour = NA) +
    geom_line(linewidth = 0.8) +
    geom_line(data = simple, aes(y = jackknife), colour = PAPER_COLOURS[["violet"]],
              linetype = "dashed", linewidth = 0.6) +
    facet_wrap(~ panel, scales = "free_y") +
    scale_colour_manual(values = IDENTIFICATION_COLOURS) +
    scale_x_continuous(breaks = 0:IRF_HORIZON) +
    labs(title = paste0("Impulse responses of the panel VAR (", gsub("_", " ", control_set), ")"),
         x = "Years after the shock", y = "Response to a one-unit shock",
         caption = paste0("Band: 95% country-cluster bootstrap (", N_BOOT, " draws) for the simple identification ",
                          "(Jaeger & Paserman fn. 12). Dashed violet: simple identification with half-panel-jackknife ",
                          "coefficients.\nCholesky lines allow a same-year effect in one direction. VAR(", N_LAGS,
                          ") with state and year FE, ", min(SAMPLE_YEARS), "-", max(SAMPLE_YEARS), ".")) +
    theme_paper()
  save_figure(figure, paste0("fig12_irf_", control_set, ".png"), 10, 6.5)
}

cumulative_plot <- cross_responses %>% filter(identification == "Simple (no same-year effect)")
figure_cumulative <- ggplot(cumulative_plot, aes(horizon, cumulative, colour = control_set, fill = control_set)) +
  geom_hline(yintercept = 0, colour = "#52514e", linewidth = 0.3) +
  geom_ribbon(aes(ymin = cumulative_lower, ymax = cumulative_upper), alpha = 0.12, colour = NA) +
  geom_line(linewidth = 0.8) +
  facet_wrap(~ panel, scales = "free_y") +
  scale_colour_manual(values = c(no_controls = PAPER_COLOURS[["blue"]], with_controls = PAPER_COLOURS[["orange"]])) +
  scale_fill_manual(values = c(no_controls = PAPER_COLOURS[["blue"]], with_controls = PAPER_COLOURS[["orange"]])) +
  scale_x_continuous(breaks = 0:IRF_HORIZON) +
  labs(title = "Cumulative responses (sum over years 0..h), simple identification",
       x = "Years after the shock", y = "Cumulative response to a one-unit shock",
       caption = paste0("95% country-cluster bootstrap bands (", N_BOOT, " draws). Jaeger & Paserman (Section V) report ",
                        "the long-run cumulative effect.")) +
  theme_paper()
save_figure(figure_cumulative, "fig13_cumulative_irf.png", 10, 6.5)


# =============================================================================
# 3. Markdown summary: cumulative effects after 2, 5 and 10 years
# =============================================================================
summary_rows <- irf_results %>%
  filter(shock != response, horizon %in% c(2, 5, 10)) %>%
  mutate(direction = ifelse(shock == "sanction", "New sanction → violence", "Violence → new sanctions"),
         significant = cumulative_lower > 0 | cumulative_upper < 0,
         cell = sprintf("%.3f [%.3f, %.3f]%s", cumulative, cumulative_lower, cumulative_upper,
                        ifelse(significant, " *", ""))) %>%
  select(direction, specification, control_set, identification, horizon, cell) %>%
  pivot_wider(names_from = horizon, values_from = cell, names_prefix = "cumulative, h = ") %>%
  arrange(direction, specification, control_set, identification)

to_markdown <- function(table) {
  c(paste0("| ", paste(names(table), collapse = " | "), " |"),
    paste0("|", paste(rep("---", ncol(table)), collapse = "|"), "|"),
    apply(table, 1, function(row) paste0("| ", paste(ifelse(is.na(row), "", row), collapse = " | "), " |")), "")
}
markdown <- c(
  "# Impulse responses (Jaeger & Paserman, Section V)", "",
  paste0("Generated by `empirics/scripts/08_irf.R` on ", format(Sys.time(), "%Y-%m-%d %H:%M"),
         ". VAR(", N_LAGS, "), state and year FE, ", N_BOOT, " country-cluster bootstrap draws. ",
         "Figures: `fig12_irf_no_controls.png`, `fig12_irf_with_controls.png`, `fig13_cumulative_irf.png`."), "",
  "Cumulative response to a one-unit shock, summed over years 0..h, with the 95% bootstrap interval; ",
  "* = interval excludes zero.", "",
  to_markdown(summary_rows),
  "*Shock units:* incidence = one new sanction / one conflict year; levels = one additional new case / ",
  "+1 in log(1 + deaths per 100,000). *simple*: no same-year effect on the other variable (JP fn. 12); ",
  "*cholesky_sanction_first*: a new sanction may change violence in the same year; ",
  "*cholesky_violence_first*: violence may trigger sanctions in the same year."
)
writeLines(markdown, file.path(TABLES, "irf_summary.md"))

cat("\nCumulative responses:\n"); print(as.data.frame(summary_rows), row.names = FALSE)
cat("\nWrote", file.path(TABLES, "irf_summary.md"), "\n")
