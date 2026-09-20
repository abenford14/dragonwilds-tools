#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/config.sh"

echo "Starting $SERVICE_NAME..."

sudo systemctl start "$SERVICE_NAME"

sleep 2

if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "Server started successfully"
else
    echo "Server failed to start"
fi
