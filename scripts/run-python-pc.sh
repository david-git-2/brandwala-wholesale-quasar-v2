#!/usr/bin/env bash
set -euo pipefail

# Runs the full UK PC product pipeline with an auto-managed root venv.
# `pnpm run python:pc` should be the only command needed:
# 1) Create/repair .venv if missing or broken (moved project, stale python)
# 2) Install/update python requirements
# 3) make pc: export → normalize → VAT/ml name clean → sync to Supabase

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="${ROOT_DIR}/.venv"
VENV_PYTHON="${VENV_DIR}/bin/python"
REQ_FILE="${ROOT_DIR}/python/requirements.txt"

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
make -C "${ROOT_DIR}/python" pc
