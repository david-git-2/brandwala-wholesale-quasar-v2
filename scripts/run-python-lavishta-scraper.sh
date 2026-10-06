#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="${ROOT_DIR}/.venv"
VENV_PYTHON="${VENV_DIR}/bin/python"
REQ_FILE="${ROOT_DIR}/python/requirements.txt"
SCRAPER="${ROOT_DIR}/python/scripts/bd/scrape_lavishta.py"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required but was not found on PATH" >&2
  exit 1
fi

if [[ ! -x "${VENV_PYTHON}" ]]; then
  echo "Creating virtual environment at ${VENV_DIR}"
  python3 -m venv "${VENV_DIR}"
fi

export PATH="${VENV_DIR}/bin:${PATH}"
"${VENV_PYTHON}" -m pip install -q -r "${REQ_FILE}"

exec "${VENV_PYTHON}" "${SCRAPER}" "$@"
