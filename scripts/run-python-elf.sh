#!/usr/bin/env bash
set -euo pipefail

# ELF International full pipeline (auto-managed venv):
# 1) Create .venv if missing
# 2) Activate venv + install requirements
# 3) Scrape → remap keys → sync to Supabase (make elf)
#    stdin closed so sync does not prompt for tenant ids
# 4) Deactivate venv

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="${ROOT_DIR}/.venv"
REQ_FILE="${ROOT_DIR}/python/requirements.txt"

if [[ ! -d "${VENV_DIR}" ]]; then
  echo "Creating virtual environment at ${VENV_DIR}"
  python3 -m venv "${VENV_DIR}"
fi

# shellcheck source=/dev/null
source "${VENV_DIR}/bin/activate"

python -m pip install -r "${REQ_FILE}"
make -C "${ROOT_DIR}/python" elf </dev/null

deactivate || true
