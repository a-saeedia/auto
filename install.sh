#!/usr/bin/env bash
set -euo pipefail

# One-line installer for Crypto News Farsi Bot
# Usage example:
# curl -fsSL https://raw.githubusercontent.com/<your-username>/crypto-news-farsi-bot/main/install.sh | bash -s -- \
#   --repo https://github.com/<your-username>/crypto-news-farsi-bot.git \
#   --bot-token '123:abc' \
#   --admin-id 123456789 \
#   --channel-id '-1001234567890' \
#   --gemini-key 'your_gemini_key' \
#   --feeds 'https://feed1.com/rss,https://feed2.com/rss'

INSTALL_DIR="${HOME}/crypto-news-farsi-bot"
SERVICE_NAME="crypto-news-farsi-bot"
PYTHON_BIN="python3"
CREATE_SERVICE="yes"

REPO_URL=""
BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
ADMIN_ID="${ADMIN_USER_ID:-}"
CHANNEL_ID="${TELEGRAM_CHANNEL_ID:-}"
GEMINI_KEY="${GEMINI_API_KEY:-}"
GEMINI_MODEL="${GEMINI_MODEL:-gemini-1.5-flash}"
NEWS_FEEDS="${NEWS_FEEDS:-}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo) REPO_URL="$2"; shift 2;;
    --install-dir) INSTALL_DIR="$2"; shift 2;;
    --no-service) CREATE_SERVICE="no"; shift 1;;
    --bot-token) BOT_TOKEN="$2"; shift 2;;
    --admin-id) ADMIN_ID="$2"; shift 2;;
    --channel-id) CHANNEL_ID="$2"; shift 2;;
    --gemini-key) GEMINI_KEY="$2"; shift 2;;
    --gemini-model) GEMINI_MODEL="$2"; shift 2;;
    --feeds) NEWS_FEEDS="$2"; shift 2;;
    --python) PYTHON_BIN="$2"; shift 2;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

if [[ -z "${REPO_URL}" ]]; then
  echo "Error: --repo <https://github.com/<user>/<repo>.git> is required."
  exit 1
fi

# Dependencies
if ! command -v git >/dev/null 2>&1; then
  echo "Installing git..."
  if command -v apt >/dev/null 2>&1; then sudo apt update && sudo apt install -y git; else
    echo "Please install git and re-run."; exit 1
  fi
fi

if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
  echo "Python not found. Please install python3 and re-run."; exit 1
fi

if ! "${PYTHON_BIN}" -m venv --help >/dev/null 2>&1; then
  echo "python3-venv not found."
  if command -v apt >/devnull 2>&1; then sudo apt update && sudo apt install -y python3-venv; else
    echo "Please install python venv package (python3-venv) and re-run."; exit 1
  fi
fi

mkdir -p "${INSTALL_DIR}"
if [[ ! -d "${INSTALL_DIR}/.git" ]]; then
  git clone "${REPO_URL}" "${INSTALL_DIR}"
else
  git -C "${INSTALL_DIR}" pull --ff-only
fi

cd "${INSTALL_DIR}"

# Python env
if [[ ! -d ".venv" ]]; then
  "${PYTHON_BIN}" -m venv .venv
fi
. .venv/bin/activate
python -m pip install --upgrade pip
pip install -r requirements.txt

# .env
ENV_FILE="${INSTALL_DIR}/.env"
touch "${ENV_FILE}"
chmod 600 "${ENV_FILE}"

set_kv() {
  local key="$1"; local val="$2"
  if grep -qE "^${key}=" "${ENV_FILE}"; then
    sed -i.bak "s|^${key}=.*|${key}=${val}|g" "${ENV_FILE}"
  else
    echo "${key}=${val}" >> "${ENV_FILE}"
  fi
}

[[ -n "$BOT_TOKEN" ]] && set_kv TELEGRAM_BOT_TOKEN "$BOT_TOKEN"
[[ -n "$CHANNEL_ID" ]] && set_kv TELEGRAM_CHANNEL_ID "$CHANNEL_ID"
[[ -n "$ADMIN_ID" ]] && set_kv ADMIN_USER_ID "$ADMIN_ID"
[[ -n "$GEMINI_KEY" ]] && set_kv GEMINI_API_KEY "$GEMINI_KEY"
[[ -n "$GEMINI_MODEL" ]] && set_kv GEMINI_MODEL "$GEMINI_MODEL"
[[ -n "$NEWS_FEEDS" ]] && set_kv NEWS_FEEDS "$NEWS_FEEDS"

echo "Wrote .env at ${ENV_FILE}"

# Service (user-level systemd if available)
if [[ "${CREATE_SERVICE}" == "yes" ]] && command -v systemctl >/dev/null 2>&1 && systemctl --user show-environment >/dev/null 2>&1; then
  UNIT_DIR="${HOME}/.config/systemd/user"
  mkdir -p "${UNIT_DIR}"
  UNIT_FILE="${UNIT_DIR}/${SERVICE_NAME}.service"
  cat > "${UNIT_FILE}" <<EOF
[Unit]
Description=Crypto News Farsi Telegram Bot
After=network-online.target

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
ExecStart=${INSTALL_DIR}/.venv/bin/python ${INSTALL_DIR}/bot.py
Restart=always
RestartSec=10
Environment=PYTHONUNBUFFERED=1

[Install]
WantedBy=default.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now "${SERVICE_NAME}.service" || true

  echo "Service installed as user unit: ${SERVICE_NAME}.service"
  echo "Tip: To keep it running after logout: loginctl enable-linger ${USER}"
  echo "Manage it with:"
  echo "  systemctl --user status ${SERVICE_NAME}"
  echo "  systemctl --user restart ${SERVICE_NAME}"
else
  echo "systemd user services unavailable or --no-service specified."
  echo "Starting bot in background with nohup..."
  nohup "${INSTALL_DIR}/.venv/bin/python" "${INSTALL_DIR}/bot.py" > "${INSTALL_DIR}/bot.log" 2>&1 &
  echo "Started. Logs: tail -f ${INSTALL_DIR}/bot.log"
fi

echo "Done."
