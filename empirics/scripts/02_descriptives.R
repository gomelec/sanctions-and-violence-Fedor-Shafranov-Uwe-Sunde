# =============================================================================
# 02_descriptives.R — descriptive figures of the analysis panel (9 figures + 1 table).
# Descriptive only: sanctions and violence are shown separately, so the figures
# do not pre-empt the choice of the main specification.
#
# Input : data/processed/sanctions_violence/sanctions_violence_panel.csv
# Output: empirics/results/figures/descriptives/fig1..fig9 (.png)
#         empirics/results/tables/tab_sanction_flows_summary.csv
#   fig1-5: stocks, violence, coverage | fig6-9 + table: sanction flows
#   (new / lifted cases, data/README.md S11; added 2026-10-20)
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

# =============================================================================
# Figs 6-9 + table: FLOW variables (new / lifted sanctions; data/README.md, S11)
# Still descriptive only: sanctions are shown on their own, not against violence.
# =============================================================================
MAIN_YEARS <- SAMPLE_YEARS            # main estimation window from 00_setup.R (1989-2019)

# =============================================================================
# Fig 6: new and lifted sanction cases per year (world, case x target pairs)
# =============================================================================
f6 <- p %>%
  group_by(yr) %>%
  summarise(New = sum(n_new_cases, na.rm = TRUE),
            Lifted = -sum(n_lifted_cases, na.rm = TRUE), .groups = "drop") %>%
  pivot_longer(-yr, names_to = "flow", values_to = "n") %>%
  mutate(flow = factor(flow, levels = c("New", "Lifted")))

lab6 <- tribble(
  ~yr,    ~n,   ~txt,
  2001.2,  128, "2002: US aid cut to ICC members (case 685)",
  2013.2,   72, "2014: Crimea; Russian counter-sanctions on EU members",
  2020.2,  178, "2021–23: US surge; Russia 2022",
  1994.2,  -86, "1995: South Africa, end of apartheid",
  2008.2, -118, "2009: case 685 ends"
)

g6 <- ggplot(f6, aes(yr, n, fill = flow)) +
  geom_col(width = 0.8) +
  geom_hline(yintercept = 0, colour = ink2, linewidth = 0.3) +
  geom_text(data = lab6, aes(yr, n, label = txt), inherit.aes = FALSE,
            hjust = 1, size = 2.7, colour = ink2) +
  scale_fill_manual(values = c(New = pal[["blue"]], Lifted = pal[["orange"]])) +
  scale_x_continuous(breaks = seq(1950, 2020, 10), expand = c(0.01, 0)) +
  scale_y_continuous(labels = abs) +
  labs(title = "Sanction flows: cases imposed (up) and lifted (down) each year",
       x = NULL, y = "Case × target pairs",
       caption = paste0("New = case begins that year (GSDB `begin`); lifted = in force the year before, not this year. ",
                        "A case against a group counts once per member state.\n",
                        "Source: GSDB v4, Gleditsch–Ward states 1950–2023. Own calculations (data/README.md, S11).")) +
  theme_desc()
save_fig(g6, "fig6_new_lifted_cases_per_year.png", 9, 4.8)

# =============================================================================
# Fig 7: share of states hit by a NEW sanction, by imposing actor
# =============================================================================
f7 <- p %>%
  group_by(yr) %>%
  summarise(across(c(new_sanction, new_us_sanction, new_eu_sanction, new_un_sanction),
                   ~ mean(.x, na.rm = TRUE) * 100), .groups = "drop") %>%
  pivot_longer(-yr, names_to = "series", values_to = "share") %>%
  mutate(series = factor(series,
                         levels = c("new_sanction", "new_us_sanction", "new_eu_sanction", "new_un_sanction"),
                         labels = c("Any sender", "United States", "EU / EEC", "UN")))
f7_cols <- setNames(unname(pal[c("blue", "orange", "aqua", "violet")]), levels(f7$series))

g7 <- ggplot(f7, aes(yr, share, colour = series)) +
  annotate("rect", xmin = min(MAIN_YEARS) - 0.5, xmax = max(MAIN_YEARS) + 0.5, ymin = -Inf, ymax = Inf,
           fill = grid_col, alpha = 0.5) +
  annotate("text", x = mean(MAIN_YEARS), y = Inf, vjust = 1.5, size = 2.8, colour = ink2,
           label = paste0("main sample ", min(MAIN_YEARS), "–", max(MAIN_YEARS))) +
  geom_line(linewidth = 0.8) +
  scale_colour_manual(values = f7_cols) +
  scale_x_continuous(breaks = seq(1950, 2020, 10), expand = c(0.01, 0)) +
  labs(title = "How often states are hit by a new sanction",
       x = NULL, y = "% of states with ≥ 1 new case",
       caption = paste0("new_sanction and new_*_sanction: at least one case beginning that year. ",
                        "2002 spike: US aid cut to ICC members (case 685, coded for 108 states).\nSource: GSDB v4, own calculations.")) +
  theme_desc()
save_fig(g7, "fig7_share_new_sanction_by_actor.png", 8, 4.6)

# =============================================================================
# Fig 8: how much variation is there? (main sample)
#   (a) distribution of n_new_cases per state-year
#   (b) number of years with a new sanction per state
# =============================================================================
ps <- p %>% filter(yr %in% MAIN_YEARS)
cap5 <- function(x) factor(pmin(x, 5), levels = 0:5, labels = c(0:4, "5+"))

f8a <- ps %>% count(k = cap5(n_new_cases)) %>%
  mutate(panel = "(a) New cases per state-year", unit = "state-years")
f8b <- ps %>% group_by(gw_name) %>% summarise(k = sum(new_sanction, na.rm = TRUE), .groups = "drop") %>%
  mutate(k = cut(k, breaks = c(-Inf, 0, 2, 5, 10, Inf), labels = c("0", "1–2", "3–5", "6–10", "11+"))) %>%
  count(k) %>% mutate(panel = "(b) Years with a new sanction, per state", unit = "states")
f8 <- bind_rows(f8a %>% mutate(k = as.character(k)), f8b %>% mutate(k = as.character(k))) %>%
  group_by(panel) %>% mutate(pct = n / sum(n) * 100, k = factor(k, levels = unique(k))) %>% ungroup()

g8 <- ggplot(f8, aes(k, n)) +
  geom_col(fill = pal[["blue"]], width = 0.7) +
  geom_text(aes(label = paste0(n, "\n(", round(pct), "%)")), vjust = -0.2, size = 2.7,
            colour = ink2, lineheight = 0.9) +
  facet_wrap(~ panel, scales = "free") +
  scale_y_continuous(expand = expansion(mult = c(0, 0.25))) +
  labs(title = paste0("Variation in new sanctions, ", min(MAIN_YEARS), "–", max(MAIN_YEARS)),
       x = NULL, y = "Count (state-years in a, states in b)",
       caption = "Most state-years have no new sanction; the events are spread over many states. Source: GSDB v4, own calculations.") +
  theme_desc() +
  theme(strip.text = element_text(colour = ink, face = "bold", hjust = 0))
save_fig(g8, "fig8_variation_new_sanctions.png", 9, 4.2)

# =============================================================================
# Fig 9: what kind of new sanctions? (share of state-years with a new sanction)
# =============================================================================
f9 <- p %>%
  filter(new_sanction == 1) %>%
  mutate(decade = paste0(floor(yr / 10) * 10, "s")) %>%
  group_by(decade) %>%
  summarise(`Arms embargo` = mean(new_arms_sanction) * 100,
            `Conflict objective` = mean(new_conflict_obj_sanction) * 100,
            `UN` = mean(new_un_sanction) * 100,
            `EU / EEC` = mean(new_eu_sanction) * 100,
            `United States` = mean(new_us_sanction) * 100,
            n = n(), .groups = "drop") %>%
  pivot_longer(-c(decade, n), names_to = "feature", values_to = "share") %>%
  mutate(feature = factor(feature, levels = c("United States", "EU / EEC", "UN", "Arms embargo", "Conflict objective")),
         decade_lab = paste0(decade, "\n(n = ", n, ")"))
f9_cols <- setNames(unname(pal[c("orange", "aqua", "violet", "red", "yellow")]), levels(f9$feature))

g9 <- ggplot(f9, aes(decade_lab, share, fill = feature)) +
  geom_col(position = position_dodge(width = 0.8), width = 0.75) +
  scale_fill_manual(values = f9_cols) +
  scale_y_continuous(limits = c(0, 100), expand = c(0, 0)) +
  labs(title = "What new sanctions look like: sender, arms embargoes and conflict objectives",
       x = NULL, y = "% of state-years with a new sanction",
       caption = paste0("Conflict objective = GSDB objective end_war, territorial_conflict or prevent_war. ",
                        "Shares within state-years with ≥ 1 new case (n); categories overlap.\nSource: GSDB v4, own calculations.")) +
  theme_desc()
save_fig(g9, "fig9_new_sanctions_by_type_decade.png", 9, 4.6)

# =============================================================================
# Table: summary statistics of the sanction variables (stock vs flows)
# =============================================================================
flow_vars <- c("n_cases_received", "any_sanction", "n_new_cases", "new_sanction",
               "new_un_sanction", "new_eu_sanction", "new_us_sanction", "new_arms_sanction",
               "new_conflict_obj_sanction", "n_lifted_cases", "lifted_sanction", "n_joined_cases")
summ <- function(d, window) {
  d %>% select(gw_name, all_of(flow_vars)) %>%
    pivot_longer(-gw_name, names_to = "variable") %>%
    group_by(variable) %>%
    summarise(mean = mean(value, na.rm = TRUE), sd = sd(value, na.rm = TRUE),
              share_nonzero = mean(value > 0, na.rm = TRUE), max = max(value, na.rm = TRUE),
              states_ever_nonzero = n_distinct(gw_name[value > 0]),
              n = sum(!is.na(value)), .groups = "drop") %>%
    mutate(sample = window, variable = factor(variable, levels = flow_vars)) %>%
    arrange(variable)
}
tab <- bind_rows(summ(p, "1950-2023"),
                 summ(ps, paste0(min(MAIN_YEARS), "-", max(MAIN_YEARS)))) %>%
  mutate(across(c(mean, sd, share_nonzero), ~ round(.x, 3)))
tab_file <- file.path(TABLES, "tab_sanction_flows_summary.csv")
write_csv(tab, tab_file)
cat("Wrote", tab_file, "\n")
print(as.data.frame(tab), row.names = FALSE)
