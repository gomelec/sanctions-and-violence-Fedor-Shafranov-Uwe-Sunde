#!/usr/bin/env bash
# Sets up everything needed to run the replication pipeline.
#   1. Python: creates .venv in this folder and installs requirements.txt
#   2. R:      installs missing R packages (setup_r_packages.R), if Rscript is found
# Usage:  bash setup_venv.sh        then:  .venv/bin/python master.py --check
set -euo pipefail
cd "$(dirname "$0")"

PY_VERSION="3.13"

if command -v uv >/dev/null 2>&1; then
  echo ">> creating .venv with uv (Python $PY_VERSION)"
  uv venv --python "$PY_VERSION" .venv
  uv pip install --python .venv/bin/python -r requirements.txt
else
  PY=""
  for c in python3.13 python3.12 python3.11 python3; do
    if command -v "$c" >/dev/null 2>&1 && "$c" -c 'import sys; sys.exit(sys.version_info < (3, 11))'; then PY="$c"; break; fi
  done
  [ -n "$PY" ] || { echo "ERROR: need Python >= 3.11 (or install uv: https://docs.astral.sh/uv/)"; exit 1; }
  echo ">> creating .venv with $PY"
  "$PY" -m venv .venv
  .venv/bin/python -m pip install --upgrade pip
  .venv/bin/python -m pip install -r requirements.txt
fi
.venv/bin/python -c "import pandas, country_converter; print('Python OK: pandas', pandas.__version__)"

if command -v Rscript >/dev/null 2>&1; then
  echo ">> checking R packages"
  Rscript setup_r_packages.R
else
  echo "!! Rscript not found: install R (https://cran.r-project.org) to run the R steps,"
  echo "   or run the Python steps only with: .venv/bin/python master.py --skip-r"
fi

echo
echo "Done. Run the pipeline with:  .venv/bin/python master.py --check"
