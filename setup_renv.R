# =============================================================================
# setup_renv.R — project R environment with renv (run once per computer)
#
#   Rscript setup_renv.R          (from the project folder)
#
# First run (no renv.lock yet): creates the project library (renv/), the
#   activation file (.Rprofile), installs the packages below and writes renv.lock
#   with their exact versions.
# Later / other computers (renv.lock exists): installs exactly the locked versions.
#
# After setup, every R session started in this folder (RStudio project, Rscript
# from master.py) uses the project library automatically via .Rprofile.
# To add a package later:  renv::install("pkg"); renv::snapshot(type = "all")
# =============================================================================

options(repos = c(CRAN = "https://cloud.r-project.org"))

PKGS <- c(
  # data pipeline (data/scripts/cleaning/clean_base.R)
  "tidyverse", "here", "peacesciencer", "countrycode", "states",
  # analysis (empirics/scripts)
  "data.table", "plm", "panelvar", "fixest", "modelsummary",
  # reports
  "rmarkdown", "knitr"
)

if (!requireNamespace("renv", quietly = TRUE)) install.packages("renv")

if (file.exists("renv.lock")) {
  cat("renv.lock found -> restoring the locked package versions\n")
  renv::restore(prompt = FALSE)
} else {
  cat("No renv.lock -> initialising renv and installing", length(PKGS), "packages\n")
  renv::init(bare = TRUE, restart = FALSE)     # renv/ + .Rprofile, nothing installed yet
  renv::load()
  failed <- character(0)
  for (p in PKGS) {
    ok <- tryCatch({ renv::install(p, prompt = FALSE); TRUE },
                   error = function(e) { message("FAILED: ", p, " - ", conditionMessage(e)); FALSE })
    if (!ok) failed <- c(failed, p)
  }
  renv::snapshot(type = "all", prompt = FALSE)  # record every package in the project library
  if (length(failed)) {
    cat("\nCould not install:", paste(failed, collapse = ", "),
        "\n(e.g. archived on CRAN: try renv::install('panelvar@<version>') or from GitHub, then renv::snapshot(type = 'all'))\n")
  }
}

cat("\nInstalled versions:\n")
for (p in PKGS) {
  v <- tryCatch(as.character(packageVersion(p)), error = function(e) "NOT INSTALLED")
  cat(sprintf("  %-14s %s\n", p, v))
}
