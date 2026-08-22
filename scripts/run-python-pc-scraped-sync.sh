#!/usr/bin/env bash
set -euo pipefail

# Runs the UK scraped PriceCheck → Supabase sync with an auto-managed root venv.
# `pnpm run python:sync:scraped-pc` should be the only command needed:
# 1) Create/repair .venv if missing or broken
# 2) Install/update python requirements
# 3) Run sync_scraped_pc_to_supabase.py

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="${ROOT_DIR}/.venv"
VENV_PYTHON="${VENV_DIR}/bin/python"
REQ_FILE="${ROOT_DIR}/python/requirements.txt"
SYNC_SCRIPT="${ROOT_DIR}/python/scripts/uk/sync_scraped_pc_to_supabase.py"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required but was not found on PATH" >&2
  exit 1
fi

venv_ok() {
  [[ -x "${VENV_PYTHON}" ]] && "${VENV_PYTHON}" -c "import sys" >/dev/null 2>&1
}

if ! venv_ok; then
  echo "Creating virtual environment at ${VENV_DIR}"
  python3 -m venv --clear "${VENV_DIR}"
fi

export PATH="${VENV_DIR}/bin:${PATH}"
"${VENV_PYTHON}" -m pip install -r "${REQ_FILE}"

exec "${VENV_PYTHON}" "${SYNC_SCRIPT}"
