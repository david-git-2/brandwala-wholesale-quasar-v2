#!/usr/bin/env bash
# Legacy: push Google Drive **delegated** secrets to Supabase for server-side edge functions.
# Thrift shipment backup uses web browser sync instead — see doc/TRADEFLOWBD_DRIVE_UPLOADER.md.

set -euo pipefail

ROOT_FOLDER_ID="${GOOGLE_DRIVE_ROOT_FOLDER_ID:-}"
CLIENT_ID="${GOOGLE_DRIVE_OAUTH_CLIENT_ID:-}"
CLIENT_SECRET="${GOOGLE_DRIVE_OAUTH_CLIENT_SECRET:-}"
REFRESH_TOKEN="${GOOGLE_DRIVE_REFRESH_TOKEN:-}"
THRIFT_FOLDER="${GOOGLE_DRIVE_THRIFT_FOLDER:-thrift}"
PUBLIC_FILES="${GOOGLE_DRIVE_PUBLIC_FILES:-true}"

if [[ -z "$ROOT_FOLDER_ID" || -z "$CLIENT_ID" || -z "$CLIENT_SECRET" || -z "$REFRESH_TOKEN" ]]; then
  echo "Required: GOOGLE_DRIVE_ROOT_FOLDER_ID, GOOGLE_DRIVE_OAUTH_CLIENT_ID,"
  echo "          GOOGLE_DRIVE_OAUTH_CLIENT_SECRET, GOOGLE_DRIVE_REFRESH_TOKEN"
  echo "Obtain a refresh token via Google OAuth for the target Gmail account."
  exit 1
fi

if ! command -v npx >/dev/null 2>&1; then
  echo "npx is required."
  exit 1
fi

echo "Setting Supabase secrets (delegated user OAuth mode)..."
npx supabase secrets set \
  "GOOGLE_DRIVE_AUTH_MODE=user_oauth" \
  "GOOGLE_DRIVE_ROOT_FOLDER_ID=$ROOT_FOLDER_ID" \
  "GOOGLE_DRIVE_THRIFT_FOLDER=$THRIFT_FOLDER" \
  "GOOGLE_DRIVE_PUBLIC_FILES=$PUBLIC_FILES" \
  "GOOGLE_DRIVE_OAUTH_CLIENT_ID=$CLIENT_ID" \
  "GOOGLE_DRIVE_OAUTH_CLIENT_SECRET=$CLIENT_SECRET" \
  "GOOGLE_DRIVE_REFRESH_TOKEN=$REFRESH_TOKEN"

echo "Deploying drive-upload and drive-delete..."
npx supabase functions deploy drive-upload
npx supabase functions deploy drive-delete

echo "Done. App users can log in with any email; uploads use the target Gmail Drive account."
