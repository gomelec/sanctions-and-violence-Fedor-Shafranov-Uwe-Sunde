# =============================================================================
# 00_setup.R — shared setup, sourced at the top of every empirics script:
#   source(here::here("empirics", "scripts", "00_setup.R"))
# One place for packages, paths and global analysis choices. Nothing else
# (no library() calls, no hard-coded paths) belongs in the individual scripts.
# Packages are installed and version-locked with renv (setup_renv.R).
# =============================================================================

suppressPackageStartupMessages({
  library(tidyverse)
  library(here)
})

# --- paths -------------------------------------------------------------------
PANEL       <- here("data", "processed", "sanctions_violence", "sanctions_violence_panel.csv")
RESULTS     <- here("empirics", "results")
FIGURES     <- file.path(RESULTS, "figures")
TABLES      <- file.path(RESULTS, "tables")
MODELS      <- file.path(RESULTS, "models")
SAMPLE_DATA <- file.path(RESULTS, "data")
for (d in c(FIGURES, TABLES, MODELS, SAMPLE_DATA)) dir.create(d, recursive = TRUE, showWarnings = FALSE)

# --- global analysis choices (to be fixed in the analysis plan) ----------------
SAMPLE_YEARS <- 1989:2019     # main sample: UCDP from 1989, GDP/population (pwt) to 2019
MIN_OBS      <- 10            # minimum non-missing observations per unit
MANUAL_EXCLUDE <- tibble(
  gw_name = c("German Democratic Republic"),
  reason  = c("dissolved 1990: too few years")
)
set.seed(20261020)            # reproducible bootstrap / jitter

# --- main specification (empirics/ANALYSIS_PLAN.md, sections 2-3) -------------
VAR_LAGS     <- 2             # lags p in both reaction functions (decision D3)
MAX_LAGS     <- 3             # longest lag used anywhere (lag grid R1); 01 keeps these pre-sample years
CONFLICT_MIN_DEATHS <- 25     # violence incidence: >= 25 organized-violence deaths (D1)
# Lagged controls, built in 01. ex_yugo_1991_2016 was removed on 2026-10-23: with state FE it was identified
# only from 2017-19 in 7 states and did not address the Yugoslavia attribution issue; that issue is now a
# robustness check (09_robustness.R, part 5). See empirics/ANALYSIS_PLAN.md, change log.
CONTROLS     <- c("ctrl_stock", "ctrl_gdp_growth", "ctrl_democracy")

# --- analysis packages: loaded on demand by the estimation scripts -------------
ANALYSIS_PKGS <- c("data.table", "plm", "panelvar", "fixest", "modelsummary")
use_analysis_packages <- function(pkgs = ANALYSIS_PKGS) {
  suppressPackageStartupMessages(invisible(lapply(pkgs, library, character.only = TRUE)))
}

# --- helpers -------------------------------------------------------------------
read_panel <- function() {
  read_csv(PANEL, show_col_types = FALSE) %>%
    mutate(yr = as.integer(substr(as.character(year), 1, 4)))
}

cat("Setup loaded | R", as.character(getRversion()),
    "| renv:", if (nzchar(Sys.getenv("RENV_PROJECT"))) "active" else "NOT active (run setup_renv.R)", "\n")
