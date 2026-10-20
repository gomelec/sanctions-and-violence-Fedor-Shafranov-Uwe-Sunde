# Installs the R packages needed by master.py (only those that are missing).
# Run once:  Rscript setup_r_packages.R
pkgs <- c(
  # data pipeline: data/scripts/cleaning/clean_base.R
  "tidyverse", "peacesciencer", "countrycode", "states", "here",
  # empirics: empirics/scripts/*.Rmd
  "plm", "data.table", "panelvar", "rmarkdown"
)
missing <- setdiff(pkgs, rownames(installed.packages()))
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")
for (p in pkgs) cat(sprintf("%-14s %s\n", p, as.character(packageVersion(p))))
