#!/bin/bash

# Load our shared Dragonwilds configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/config.sh"

# SteamCMD location
STEAMCMD="/home/steam/.local/share/Steam/steamcmd/linux32/steamcmd"

# Installed Steam manifest
MANIFEST="$SERVER_DIR/steamapps/appmanifest_${APP_ID}.acf"


echo "========================================"
echo "Dragonwilds update check"
echo "========================================"

echo "Checking Steam for latest build..."

# Ask SteamCMD for the latest public build ID
LATEST_BUILD=$(
    sudo -u "$STEAM_USER" "$STEAMCMD" \
        +login anonymous \
        +app_info_update 1 \
        +app_info_print "$APP_ID" \
        +quit 2>&1 |
    grep -A 5 '"public"' |
    grep '"buildid"' |
    head -n 1 |
    awk -F'"' '{print $4}'
)

# Read the build ID currently installed
INSTALLED_BUILD=$(
    grep '"buildid"' "$MANIFEST" |
    awk -F'"' '{print $4}'
)

if [ -z "$LATEST_BUILD" ]; then
    echo "ERROR: Could not determine latest Steam build."
    exit 2
fi

if [ -z "$INSTALLED_BUILD" ]; then
    echo "ERROR: Could not determine installed build."
    exit 2
fi

if ! [[ "$LATEST_BUILD" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Steam returned an invalid build ID: $LATEST_BUILD"
    exit 2
fi

echo "Latest public build : $LATEST_BUILD"
echo "Installed build     : $INSTALLED_BUILD"

if [ "$LATEST_BUILD" = "$INSTALLED_BUILD" ]; then
    echo "Dragonwilds is up to date."
    exit 0
fi

echo "An update is available!"
echo "Update functionality is not enabled yet."
exit 1
