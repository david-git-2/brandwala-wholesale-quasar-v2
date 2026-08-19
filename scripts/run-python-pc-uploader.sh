#!/usr/bin/env bash
set -euo pipefail

# Local PC Excel uploader (Streamlit). Same venv as `pnpm run python:pc`.
# `pnpm run pc:uploader` should be the only command needed.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="${ROOT_DIR}/.venv"
VENV_PYTHON="${VENV_DIR}/bin/python"
REQ_FILE="${ROOT_DIR}/python/requirements.txt"
APP_FILE="${ROOT_DIR}/python/pc_uploader/app.py"

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
exec "${VENV_PYTHON}" -m streamlit run "${APP_FILE}"
