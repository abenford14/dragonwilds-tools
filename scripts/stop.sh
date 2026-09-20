#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/config.sh"

echo "Stopping $SERVICE_NAME..."

sudo systemctl stop "$SERVICE_NAME"

sleep 2

if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "Server failed to stop"
    exit 1
else
    echo "Server stopped successfully"
    exit 0
fi
