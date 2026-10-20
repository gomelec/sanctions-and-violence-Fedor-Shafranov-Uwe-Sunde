# =============================================================================
# 02_descriptives.R — descriptive figures of the analysis panel (5 figures).
# Descriptive only: sanctions and violence are shown separately, so the figures
# do not pre-empt the choice of the main specification.
#
# Input : data/processed/sanctions_violence/sanctions_violence_panel.csv
# Output: empirics/results/figures/descriptives/fig1..fig5 (.png)
# Run   : uv run python master.py --stage empirics   (or source in RStudio)
# =============================================================================

source(here::here("empirics", "scripts", "00_setup.R"))

out_dir <- file.path(FIGURES, "descriptives")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# --- colours (reference palette, light mode) and theme -------------------------
pal <- c(blue = "#2a78d6", orange = "#eb6834", aqua = "#1baf7a",
         yellow = "#eda100", violet = "#6250d6", red = "#e34948")
ink <- "#0b0b0b"; ink2 <- "#52514e"; muted <- "#8a8984"; grid_col <- "#e6e5e1"; surf <- "#fcfcfb"
seq_cols <- c("#f2f6fc", "#9cc0ef", "#2a78d6", "#123c75")   # one hue, light -> dark
na_col <- "#d9d8d3"                                          # missing / not in the system

theme_desc <- function() {
  theme_minimal(base_size = 10) +
    theme(
      plot.background  = element_rect(fill = surf, colour = NA),
      panel.background = element_rect(fill = surf, colour = NA),
      panel.grid.major = element_line(colour = grid_col, linewidth = 0.4),
      panel.grid.minor = element_blank(),
      axis.text  = element_text(colour = ink2),
      axis.title = element_text(colour = ink2),
      plot.title = element_text(colour = ink, face = "bold", size = 12),
      plot.title.position = "plot",
      plot.caption = element_text(colour = muted, size = 7.5, hjust = 0),
      plot.caption.position = "plot",
      legend.position = "top", legend.justification = "left",
      legend.title = element_blank(), legend.text = element_text(colour = ink2)
    )
}

save_fig <- function(p, name, w, h) {
  ggsave(file.path(out_dir, name), p, width = w, height = h, dpi = 200, bg = surf)
  cat("Wrote", file.path(out_dir, name), "\n")
}

# --- data ----------------------------------------------------------------------
p <- read_panel()

# =============================================================================
# Fig 1: share of states under sanctions, by imposing actor
# =============================================================================
f1 <- p %>%
  group_by(yr) %>%
  summarise(across(c(any_sanction, us_sanction, eu_sanction, un_sanction, ru_sanction), ~ mean(.x, na.rm = TRUE) * 100),
            .groups = "drop") %>%
  pivot_longer(-yr, names_to = "series", values_to = "share") %>%
  mutate(series = factor(series,
                         levels = c("any_sanction", "us_sanction", "eu_sanction", "un_sanction", "ru_sanction"),
                         labels = c("Any sanction", "United States", "EU / EEC", "UN", "Russia / USSR")))
f1_cols <- setNames(unname(pal[c("blue", "orange", "aqua", "violet", "yellow")]), levels(f1$series))
# end labels, spread at least 4.5 points apart so they do not overlap
f1_last <- f1 %>% filter(yr == max(yr)) %>% arrange(share) %>%
  mutate(label_y = accumulate(share, ~ max(.y, .x + 4.5)))

g1 <- ggplot(f1, aes(yr, share, colour = series)) +
  geom_line(linewidth = 0.9) +
  geom_text(data = f1_last, aes(y = label_y, label = series), hjust = 0, nudge_x = 1, size = 3.2,
            colour = ink2, show.legend = FALSE) +
  # group cases that GSDB expands to all members (data/README.md, S10)
  annotate("segment", x = 1990, xend = 2002, y = 69, yend = 77, colour = muted, linewidth = 0.3) +
  annotate("text", x = 1984, y = 66, size = 2.8, colour = ink2,
           label = "2002–08: US aid cut to ICC members\n(case 685, coded for 108 states)") +
  annotate("segment", x = 1998, xend = 2013.6, y = 15, yend = 17, colour = muted, linewidth = 0.3) +
  annotate("text", x = 1988, y = 13.5, size = 2.8, colour = ink2,
           label = "2014: Russian counter-sanctions\non EU members (case 995)") +
  annotate("segment", x = 1966, xend = 1976.5, y = 49, yend = 30, colour = muted, linewidth = 0.3) +
  annotate("text", x = 1962, y = 54, size = 2.8, colour = ink2,
           label = "1976: US anti-boycott measures\nvs Arab League members (case 199)") +
  scale_colour_manual(values = f1_cols) +
  scale_x_continuous(limits = c(1950, 2032), breaks = seq(1950, 2030, 10), expand = c(0, 0)) +
  scale_y_continuous(limits = c(0, 100)) +
  labs(title = "The rise of sanctions: share of states under at least one sanction",
       x = NULL, y = "% of states targeted",
       caption = "Source: GSDB v4 (case-based measures), Gleditsch–Ward states 1950–2023. Own calculations.") +
  theme_desc()
save_fig(g1, "fig1_share_sanctioned_by_actor.png", 8, 4.6)

# =============================================================================
# Fig 2: senders vs cases — what num_sanctioners actually measures
# =============================================================================
f2 <- p %>%
  filter(any_sanction == 1) %>%
  mutate(un = factor(un_sanction, levels = c(0, 1), labels = c("No UN case", "At least one UN case")))

g2 <- ggplot(f2, aes(n_cases_received, num_sanctioners, colour = un)) +
  geom_point(position = position_jitter(width = 0.25, height = 0, seed = 1),
             size = 1.3, alpha = 0.45) +
  scale_colour_manual(values = c("No UN case" = pal[["blue"]], "At least one UN case" = pal[["orange"]])) +
  labs(title = "Sender counts jump to ~190 whenever the UN acts",
       x = "Number of sanction cases against the state (n_cases_received)",
       y = "Number of sanctioning countries (num_sanctioners)",
       caption = "Each dot is a sanctioned state-year (1950–2023), horizontal jitter added. GSDB codes UN cases as one row per member state.") +
  theme_desc() +
  theme(legend.position = c(0.85, 0.5)) +
  guides(colour = guide_legend(override.aes = list(alpha = 1, size = 2.5)))
save_fig(g2, "fig2_senders_vs_cases.png", 8, 4.9)

# =============================================================================
# Fig 3: organized-violence deaths by type, world total
# =============================================================================
f3 <- p %>%
  filter(yr >= 1989) %>%
  group_by(yr) %>%
  summarise(across(c(sb_total_deaths_best, ns_total_deaths_best, os_total_deaths_best),
                   ~ sum(.x, na.rm = TRUE) / 1000), .groups = "drop") %>%
  pivot_longer(-yr, names_to = "type", values_to = "deaths") %>%
  mutate(type = factor(type,
                       levels = c("sb_total_deaths_best", "ns_total_deaths_best", "os_total_deaths_best"),
                       labels = c("State-based conflict", "Non-state conflict", "One-sided violence")))
f3_cols <- setNames(unname(pal[c("blue", "aqua", "orange")]), levels(f3$type))

labs3 <- tribble(
  ~yr,  ~type,                  ~txt,
  1994, "One-sided violence",   "Rwanda genocide",
  2000, "State-based conflict", "Ethiopia–Eritrea",
  2014, "State-based conflict", "Syria, Iraq",
  2022, "State-based conflict", "Ethiopia (Tigray), Ukraine"
) %>%
  mutate(type = factor(type, levels = levels(f3$type))) %>%
  left_join(f3, by = c("yr", "type"))

g3 <- ggplot(f3, aes(yr, deaths, colour = type)) +
  geom_line(linewidth = 0.9) +
  geom_text(data = labs3, aes(label = txt), vjust = -0.8, size = 2.9, colour = ink2, show.legend = FALSE) +
  scale_colour_manual(values = f3_cols) +
  scale_y_continuous(limits = c(0, max(f3$deaths) * 1.12)) +
  labs(title = "Organized violence: deaths per year by type of violence",
       x = NULL, y = "Deaths, thousands (best estimate)",
       caption = "Source: UCDP Organized Violence Country-Year v26.1, summed over Gleditsch–Ward states. Own calculations.") +
  theme_desc()
save_fig(g3, "fig3_violence_deaths_by_type.png", 8, 4.6)

# =============================================================================
# Fig 4: heatmap of the 20 most sanctioned states (case-years)
# =============================================================================
top20 <- p %>%
  group_by(gw_name) %>%
  summarise(case_years = sum(n_cases_received, na.rm = TRUE), .groups = "drop") %>%
  slice_max(case_years, n = 20, with_ties = FALSE) %>%
  pull(gw_name)

f4 <- p %>%
  filter(gw_name %in% top20) %>%
  select(gw_name, yr, n_cases_received) %>%
  complete(gw_name, yr = full_seq(p$yr, 1)) %>%          # years a state did not exist -> NA (gray)
  mutate(label = sub(" \\(.*", "", gw_name),
         label = factor(label, levels = rev(sub(" \\(.*", "", top20))))

g4 <- ggplot(f4, aes(yr, label, fill = n_cases_received)) +
  geom_tile() +
  scale_fill_gradientn(colours = seq_cols, na.value = na_col, name = "Sanction cases\nin force") +
  scale_x_continuous(breaks = seq(1950, 2020, 10), expand = c(0, 0)) +
  labs(title = "Who is sanctioned, and when: the 20 most-sanctioned states",
       x = NULL, y = NULL,
       caption = "Ranking by total case-years 1950–2023. Source: GSDB v4, own calculations. Gray = state not in the system that year.") +
  theme_desc() +
  theme(panel.grid = element_blank(), legend.position = "right",
        legend.title = element_text(colour = ink2, size = 8))
save_fig(g4, "fig4_heatmap_most_sanctioned.png", 10, 6)

# =============================================================================
# Fig 5: data coverage of the main variables
# =============================================================================
cov_vars <- c("Sanctions (GSDB)"         = "num_sanctioners",
              "Deaths per capita (UCDP)" = "cumulative_total_deaths_parties_in_orgvio_pc",
              "Conflict events (GDELT)"  = "total_violence_norm1000",
              "Democracy (V-Dem)"        = "v2x_polyarchy",
              "GDP per capita"           = "gdp_ext",
              "Population"               = "pop_ext")

f5 <- p %>%
  group_by(yr) %>%
  summarise(across(all_of(unname(cov_vars)), ~ mean(!is.na(.x)) * 100), .groups = "drop") %>%
  pivot_longer(-yr, names_to = "var", values_to = "coverage") %>%
  mutate(var = factor(var, levels = rev(unname(cov_vars)), labels = rev(names(cov_vars))))

g5 <- ggplot(f5, aes(yr, var, fill = coverage)) +
  geom_tile() +
  scale_fill_gradientn(colours = seq_cols, limits = c(0, 100), name = "% of states\nwith data") +
  scale_x_continuous(breaks = seq(1950, 2020, 10), expand = c(0, 0)) +
  labs(title = "Where the data are: coverage of the main variables",
       x = NULL, y = NULL,
       caption = "Share of Gleditsch–Ward states with a non-missing value, by year. UCDP starts 1989, GDELT covers 1979–2021.") +
  theme_desc() +
  theme(panel.grid = element_blank(), legend.position = "right",
        legend.title = element_text(colour = ink2, size = 8))
save_fig(g5, "fig5_data_coverage.png", 10, 3.4)
