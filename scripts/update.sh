#!/bin/bash

# Load shared Dragonwilds configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/config.sh"

# Installed Steam manifest
MANIFEST="$SERVER_DIR/steamapps/appmanifest_${APP_ID}.acf"

echo "========================================"
echo "Dragonwilds updater"
echo "========================================"

#
# STEP 1 - Find the latest public build
#

echo "Checking Steam for latest build..."

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

#
# STEP 2 - Find the installed build
#

INSTALLED_BUILD=$(
    grep '"buildid"' "$MANIFEST" |
    awk -F'"' '{print $4}'
)

#
# STEP 3 - Validate what we found
#

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

if ! [[ "$INSTALLED_BUILD" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Installed build ID is invalid: $INSTALLED_BUILD"
    exit 2
fi

echo "Latest public build : $LATEST_BUILD"
echo "Installed build     : $INSTALLED_BUILD"

#
# STEP 4 - Nothing to do if versions match
#

if [ "$LATEST_BUILD" = "$INSTALLED_BUILD" ]; then
    echo "Dragonwilds is up to date."
    exit 0
fi

#
# STEP 5 - An update is available
#

echo ""
echo "========================================"
echo "Update available!"
echo "========================================"
echo "From build : $INSTALLED_BUILD"
echo "To build   : $LATEST_BUILD"
echo ""

#
# STEP 6 - Stop the server
#

echo "Stopping Dragonwilds server..."

if ! "$SCRIPT_DIR/stop.sh"; then
    echo "ERROR: Server failed to stop."
    exit 3
fi

#
# STEP 7 - Update through SteamCMD
#

echo "Updating server files..."

sudo -u "$STEAM_USER" "$STEAMCMD" \
    +force_install_dir "$SERVER_DIR" \
    +login anonymous \
    +app_update "$APP_ID" \
    +quit

STEAM_EXIT_CODE=$?

if [ "$STEAM_EXIT_CODE" -ne 0 ]; then
    echo "ERROR: SteamCMD update failed."
    echo "SteamCMD exit code: $STEAM_EXIT_CODE"
    exit 4
fi

echo "SteamCMD update completed."

#
# STEP 8 - Verify the installed build
#

NEW_INSTALLED_BUILD=$(
    grep '"buildid"' "$MANIFEST" |
    awk -F'"' '{print $4}'
)

echo "Installed build after update: $NEW_INSTALLED_BUILD"

if [ "$NEW_INSTALLED_BUILD" != "$LATEST_BUILD" ]; then
    echo "ERROR: Installed build does not match expected build."
    echo "Expected: $LATEST_BUILD"
    echo "Found:    $NEW_INSTALLED_BUILD"
    echo ""
    echo "Server will remain stopped."
    exit 4
fi

echo "Build verification successful."

#
# STEP 9 - Start the server
#

echo "Starting Dragonwilds server..."

if ! "$SCRIPT_DIR/start.sh"; then
    echo "ERROR: Server failed to start."
    exit 5
fi

echo ""
echo "========================================"
echo "Dragonwilds update completed"
echo "========================================"
echo "Running build: $NEW_INSTALLED_BUILD"

exit 0
