#!/bin/bash

# Find project root and load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/config.sh"

echo "===================================="
echo " Dragonwilds Server Status"
echo "===================================="

if systemctl is-active --quiet "$SERVICE_NAME"; then
    echo "Status : Running"
else
    echo "Status : Stopped"
fi

echo ""

systemctl status "$SERVICE_NAME" --no-pager
