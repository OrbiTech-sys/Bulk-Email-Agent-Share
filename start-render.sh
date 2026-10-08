#!/bin/sh
set -eu

DATA_DIR="${BULK_EMAIL_DATA_DIR:-/files}"
USER_DIR="${N8N_USER_FOLDER:-/files/n8n}"

mkdir -p "$DATA_DIR/prompts" "$DATA_DIR/reviews" "$DATA_DIR/reports" "$DATA_DIR/logs" "$USER_DIR"

# Seed editable runtime assets into the persistent disk on first boot only.
if [ ! -f "$DATA_DIR/prompts/system_prompt.txt" ]; then
  cp /opt/bulk-email-agent/prompts/system_prompt.txt "$DATA_DIR/prompts/system_prompt.txt"
fi
if [ ! -f "$DATA_DIR/suppression.csv" ]; then
  printf 'email,reason,added_at\n' > "$DATA_DIR/suppression.csv"
fi

# Import the packaged workflows once. Credentials are intentionally not packaged.
if [ ! -f "$USER_DIR/.bulk-email-agent-imported" ]; then
  n8n import:workflow --input=/opt/bulk-email-agent/workflows/bulk_email_agent.json
  n8n import:workflow --input=/opt/bulk-email-agent/workflows/unsubscribe_webhook.json
  touch "$USER_DIR/.bulk-email-agent-imported"
fi

# Render does not expand ${VAR} inside render.yaml values, so build the public URLs here.
# A real value set in the dashboard (e.g. a custom domain) is kept.
if [ -n "${RENDER_EXTERNAL_URL:-}" ]; then
  case "${WEBHOOK_URL:-}" in ''|*'$'*) export WEBHOOK_URL="${RENDER_EXTERNAL_URL%/}/" ;; esac
  case "${N8N_EDITOR_BASE_URL:-}" in ''|*'$'*) export N8N_EDITOR_BASE_URL="${RENDER_EXTERNAL_URL%/}" ;; esac
fi

exec n8n start
