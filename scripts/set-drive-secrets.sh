#!/usr/bin/env bash
# Legacy: push Google Drive service-account secrets for server-side edge functions.
# Thrift shipment backup uses web browser sync instead — see doc/TRADEFLOWBD_DRIVE_UPLOADER.md.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CREDS_FILE="${GOOGLE_SERVICE_ACCOUNT_FILE:-$ROOT_DIR/python/credentials/google-service-account.json}"
ROOT_FOLDER_ID="${GOOGLE_DRIVE_ROOT_FOLDER_ID:-}"
THRIFT_FOLDER="${GOOGLE_DRIVE_THRIFT_FOLDER:-thrift}"

if [[ ! -f "$CREDS_FILE" ]]; then
  echo "Missing service account JSON: $CREDS_FILE"
  echo "Copy your Google service account key to that path (legacy server-side Drive only)."
  exit 1
fi

if [[ -z "$ROOT_FOLDER_ID" ]]; then
  echo "GOOGLE_DRIVE_ROOT_FOLDER_ID is required."
  echo "Example: GOOGLE_DRIVE_ROOT_FOLDER_ID=1AbCdEf... npm run secrets:drive"
  exit 1
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "npx is required."
  exit 1
fi

JSON_MINIFIED="$(python3 -c 'import json,sys; print(json.dumps(json.load(open(sys.argv[1]))))' "$CREDS_FILE")"

echo "Setting Supabase secrets..."
npx supabase secrets set \
  "GOOGLE_DRIVE_ROOT_FOLDER_ID=$ROOT_FOLDER_ID" \
  "GOOGLE_DRIVE_THRIFT_FOLDER=$THRIFT_FOLDER" \
  "GOOGLE_SERVICE_ACCOUNT_JSON=$JSON_MINIFIED"

echo "Deploying drive-upload and drive-delete edge functions..."
npx supabase functions deploy drive-upload
npx supabase functions deploy drive-delete

echo "Done. Service account email (share your Drive folder with this address as Editor):"
python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["client_email"])' "$CREDS_FILE"
