
#!/bin/bash

# Load shared Dragonwilds configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/config.sh"

TITLE="${1:-Dragonwilds notification}"
MESSAGE="${2:-No details provided.}"

# Never fail the calling operation because Discord is unavailable
if [ -z "${DISCORD_WEBHOOK_URL:-}" ]; then
    echo "WARNING: DISCORD_WEBHOOK_URL is not configured." >&2
    exit 0
fi

if ! command -v curl >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1; then
    echo "WARNING: curl and python3 are required for Discord notifications." >&2
    exit 0
fi

# Safely encode the message as JSON
PAYLOAD=$(python3 -c '
import json, sys
print(json.dumps({
    "embeds": [{
        "title": sys.argv[1],
        "description": sys.argv[2]
    }]
}))
' "$TITLE" "$MESSAGE") || {
    echo "WARNING: Could not encode Discord notification." >&2
    exit 0
}

# Send the notification; do not expose the webhook URL in logs
HTTP_CODE=$(curl -sS \
    -o /dev/null \
    -w '%{http_code}' \
    --connect-timeout 5 \
    --max-time 10 \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    "$DISCORD_WEBHOOK_URL") || {
    echo "WARNING: Could not reach Discord webhook." >&2
    exit 0
}

if [ "$HTTP_CODE" != "204" ]; then
    echo "WARNING: Discord webhook returned HTTP $HTTP_CODE." >&2
    exit 0
fi

echo "Discord notification sent."
