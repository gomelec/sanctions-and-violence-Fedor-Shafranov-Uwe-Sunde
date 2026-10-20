# =============================================================================
# clean_base.R
# Build the Gleditsch-Ward state-year skeleton (1946-2023) with ISO3 codes,
# UCDP/PRIO armed-conflict counts, democracy and simulated GDP/population.
#
# Source : R packages peacesciencer, states, countrycode (no local raw file;
#          peacesciencer ships/downloads its own data)
# Output : data/clean/base/base.csv   (formerly data/data_clean/final.csv)
#
# Refactored 1:1 from archive/notebooks/data_gather_R.ipynb (cells 0, 2, 3, 7, 8, 10).
# View()/check cells dropped; logic unchanged.
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(peacesciencer)
  library(countrycode)
  library(dplyr)
  library(states)
  library(here)
})
data(gwstates)
data(ucdp_acd)

out_dir <- here("data", "clean", "base")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# --- Step 1: GW state-years, CoW codes, gwc letter codes, ISO3 -----------------
base <- create_stateyears(system = "gw", subset_years = c(1946:2023)) %>%
  add_ccode_to_gw() %>%
  left_join(
    gwstates %>% select(gwcode, gwc, start, end),
    by = "gwcode",
    relationship = "many-to-many"
  ) %>%
  filter(year >= year(start) & year <= year(end)) %>%
  select(-start, -end)%>%
  mutate(iso3c = countrycode(gwcode, "gwn", "iso3c"))

base <- base %>%
  mutate(
    gw_name = case_when(
      gwcode == 403 ~ "Sao Tome and Principe",  # São Tomé and Príncipe
      gwcode == 437 ~ "Ivory Coast",                     # Côte d'Ivoire
      TRUE ~ gw_name
    )
  )

# --- Step 2: living microstates countrycode just misses (safe hard-code) ---
manual_iso3 <- c(
  # microstates countrycode just misses
  "54"  = "DMA", "55" = "GRD", "56" = "LCA", "57" = "VCT", "58" = "ATG", "60" = "KNA",
  "221" = "MCO", "223" = "LIE", "232" = "AND", "331" = "SMR", "591" = "SYC",
  "935" = "VUT", "970" = "KIR", "971" = "NRU", "972" = "TON", "973" = "TUV",
  "983" = "MHL", "986" = "PLW", "987" = "FSM", "990" = "WSM",
  "403" = "STP", "437" = "CIV",
  # historical states' own period ISO3 (not a successor mapping)
  "315" = "CSK",  # Czechoslovakia
  "265" = "DDR",  # East Germany
  "345" = "YUG",  # Yugoslavia (SFRY)
  "680" = "YMD",  # South Yemen (People's Democratic Republic)
  "678" = "YEM",  # North Yemen (Yemen Arab Republic) — kept the continuing code
  "816" = "VDR",  # North Vietnam (Democratic Republic) — distinct retired code
  "817" = "VNM",   # South Vietnam (Republic of) — kept the continuing code
  "347" = "KSV"   # Kosovo
)

base <- base %>%
  mutate(iso3c = if_else(
    is.na(iso3c) & as.character(gwcode) %in% names(manual_iso3),
    manual_iso3[as.character(gwcode)],
    iso3c
  ))

# --- Step 3: historical/dissolved states — no living ISO3, keep iso3c as NA,
#     but add a SEPARATE successor_iso3c column for merges that need one ---
successor_map <- c(
  "265" = "DEU",  # East Germany -> Germany
  "260" = "DEU",  # West Germany -> Germany
  "315" = "CZE",  # Czechoslovakia -> Czechia (judgment call; could split CZE/SVK by year if needed)
  "345" = "SRB",  # Yugoslavia -> Serbia (Miller's convention; revisit if your DV is territorial)
  "680" = "YEM",  # South Yemen -> Yemen
  "711" = "CHN",  # Tibet -> China (if relevant to your scope)
  "817" = "VNM",  # South Vietnam -> Vietnam
  "347" = "XKX"   # Kosovo -- only if your other sources use this convention
)

base <- base %>%
  mutate(successor_iso3c = if_else(
    as.character(gwcode) %in% names(successor_map),
    successor_map[as.character(gwcode)],
    NA_character_
  ))

# --- CHANGED 2026-10-20: one state for 2006 -------------------------------------
# The GW list has both Yugoslavia (345, ends 2006) and Serbia (340, starts 2006) in 2006.
# Keep only Serbia: GSDB and GDELT already code 2006 as Serbia (see data/README.md, B10).
base <- base %>% filter(!(gwcode == 345 & year == 2006))

# check (printed to the log): should only show units with genuinely no ISO3
print(base %>% filter(is.na(iso3c)) %>% distinct(gwcode, gw_name))

# --- Step 4: UCDP/PRIO ACD conflict counts by type -----------------------------
# CHANGED 2026-10-20: peacesciencer stores type_of_conflict as text labels
# ("extrasystemic", "interstate", "intrastate", "II"), not UCDP's numbers 1-4, so the
# original numeric filters matched nothing and the three type counts were all 0.
# The filters below accept both codings (numbers are compared as text: "3" etc.).
print(table(ucdp_acd$type_of_conflict, useNA = "ifany"))
# all types pooled
ucdp_acd %>%
  group_by(gwno_a, year) %>%
  summarize(n_conflicts_all = n_distinct(conflict_id)) %>%
  rename(gwcode = gwno_a) -> conflict_counts_all

# intrastate + II
ucdp_acd %>%
  filter(type_of_conflict %in% c("3", "4", "intrastate", "II")) %>%
  group_by(gwno_a, year) %>%
  summarize(n_conflicts_intra = n_distinct(conflict_id)) %>%
  rename(gwcode = gwno_a) -> conflict_counts_intra

# interstate
ucdp_acd %>%
  filter(type_of_conflict %in% c("2", "interstate")) %>%
  group_by(gwno_a, year) %>%
  summarize(n_conflicts_inter = n_distinct(conflict_id)) %>%
  rename(gwcode = gwno_a) -> conflict_counts_inter

# extrasystemic
ucdp_acd %>%
  filter(type_of_conflict %in% c("1", "extrasystemic")) %>%
  group_by(gwno_a, year) %>%
  summarize(n_conflicts_extra = n_distinct(conflict_id)) %>%
  rename(gwcode = gwno_a) -> conflict_counts_extra

# join everything onto the state-year frame
final <- base %>%
  left_join(conflict_counts_all, by = c("gwcode", "year")) %>%
  left_join(conflict_counts_intra, by = c("gwcode", "year")) %>%
  left_join(conflict_counts_inter, by = c("gwcode", "year")) %>%
  left_join(conflict_counts_extra, by = c("gwcode", "year")) %>%
  mutate(across(starts_with("n_conflicts"), ~replace_na(.x, 0)))

# sanity check: the type-specific counts must not all be zero
for (v in c("n_conflicts_intra", "n_conflicts_inter", "n_conflicts_extra")) {
  n_pos <- sum(final[[v]] > 0)
  cat(v, ": country-years with >= 1 conflict =", n_pos, "\n")
  if (n_pos == 0) stop(v, " is zero everywhere - check how type_of_conflict is coded")
}

# --- Step 5: democracy + simulated GDP / population ----------------------------
final <- final %>%
  add_democracy() %>%
  add_sim_gdp_pop()

# check (printed to the log)
print(final %>% filter(is.na(polity2)) %>% distinct(gwcode, gw_name))

# --- Write ---------------------------------------------------------------------
write.csv(final, file.path(out_dir, "base.csv"), row.names = FALSE, fileEncoding = "UTF-8")
cat("Wrote", file.path(out_dir, "base.csv"), ":", nrow(final), "rows x", ncol(final), "cols\n")
