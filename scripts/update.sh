#!/bin/bash

# Load shared Dragonwilds configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../config/config.sh"

# Send Discord notifications without interrupting the update
notify() {
    "$SCRIPT_DIR/notify.sh" "$1" "$2" || true
}

# Report a failure and the current server state
notify_failure() {
    local stage="$1"
    local details="$2"
    local server_state="not running"

    if systemctl is-active --quiet dragonwilds.service; then
        server_state="running"
    fi

    notify \
        "Dragonwilds update failed" \
        "Stage: $stage
Details: $details
Server status: $server_state"
}

# Installed Steam manifest
MANIFEST="$SERVER_DIR/steamapps/appmanifest_${APP_ID}.acf"

echo "========================================"
echo "Dragonwilds updater"
echo "========================================"

#
# STEP 1 - Find the latest public Linux depot manifest
#

echo "Checking Steam for latest Linux server depot..."

APP_INFO=$(
    sudo -u "$STEAM_USER" "$STEAMCMD" \
        +login anonymous \
        +app_info_update 1 \
        +app_info_print "$APP_ID" \
        +quit 2>&1
)

LATEST_MANIFEST=$(
    printf '%s\n' "$APP_INFO" |
    awk '
        /"3501791"/ { depot=1 }
        depot && /"public"/ { public=1 }
        public && /"gid"/ {
            gsub(/"/, "", $2)
            print $2
            exit
        }
    '
)

#
# STEP 2 - Find the installed Linux depot manifest
#

INSTALLED_MANIFEST=$(
    awk '
        /"3501791"/ { depot=1 }
        depot && /"manifest"/ {
            gsub(/"/, "", $2)
            print $2
            exit
        }
    ' "$MANIFEST"
)

#
# STEP 3 - Validate what we found
#

if [ -z "$LATEST_MANIFEST" ]; then
    echo "ERROR: Could not determine latest Linux depot manifest."
    notify_failure "Installed manifest lookup" \
        "Could not determine the installed Linux depot manifest."
    exit 2
fi

if [ -z "$INSTALLED_MANIFEST" ]; then
    echo "ERROR: Could not determine installed Linux depot manifest."
    notify_failure "Installed manifest lookup" \
        "Could not determine the installed Linux depot manifest."
    exit 2
fi

echo "Latest Linux manifest     : $LATEST_MANIFEST"
echo "Installed Linux manifest  : $INSTALLED_MANIFEST"

#
# STEP 4 - Nothing to do if manifests match
#

if [ "$LATEST_MANIFEST" = "$INSTALLED_MANIFEST" ]; then
    echo "Dragonwilds Linux server is up to date."
    exit 0
fi

#
# STEP 5 - An update is available
#

echo ""
echo "========================================"
echo "Linux server update available!"
echo "========================================"
echo "From manifest : $INSTALLED_MANIFEST"
echo "To manifest   : $LATEST_MANIFEST"
echo ""

notify \
    "Dragonwilds update starting" \
    "A Linux server update is available.
Previous manifest: $INSTALLED_MANIFEST
Target manifest: $LATEST_MANIFEST
The server will now stop while the update is installed."

#
# STEP 6 - Stop the server
#

echo "Stopping Dragonwilds server..."

if ! "$SCRIPT_DIR/stop.sh"; then
    echo "ERROR: Server failed to stop."
    notify_failure "Stopping server" \
        "stop.sh failed. The update has been aborted."
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
    notify_failure "SteamCMD update" \
        "SteamCMD returned exit code $STEAM_EXIT_CODE. The server may need manual attention."
    exit 4
fi

echo "SteamCMD update completed."

#
# STEP 8 - Verify the installed Linux depot manifest
#

NEW_INSTALLED_MANIFEST=$(
    awk '
        /"3501791"/ { depot=1 }
        depot && /"manifest"/ {
            gsub(/"/, "", $2)
            print $2
            exit
        }
    ' "$MANIFEST"
)

echo "Installed Linux manifest after update: $NEW_INSTALLED_MANIFEST"

if [ -z "$NEW_INSTALLED_MANIFEST" ] || [  "$NEW_INSTALLED_MANIFEST" != "$LATEST_MANIFEST" ]; then
    echo "ERROR: Installed Linux manifest does not match expected manifest."
    echo "Expected: $LATEST_MANIFEST"
    echo "Found:    $NEW_INSTALLED_MANIFEST"
    echo ""
    echo "Server will remain stopped."
    notify_failure "Manifest verification" \
        "Expected manifest: $LATEST_MANIFEST
Installed manifest: ${NEW_INSTALLED_MANIFEST:-unknown}
Verification failed. The server has been left stopped."
    exit 4
fi

echo "Linux depot manifest verification successful."

#
# STEP 9 - Start the server
#

echo "Starting Dragonwilds server..."

if ! "$SCRIPT_DIR/start.sh"; then
    echo "ERROR: Server failed to start."
    notify_failure "Server startup" \
        "start.sh failed after the update was installed."
    exit 5
fi
if ! systemctl is-active --quiet dragonwilds.service; then
    echo "ERROR: Server service is not active after start.sh."

    notify_failure "Server startup verification" \
        "start.sh returned successfully, but systemd reports that the service is not active."

    exit 5
fi

echo ""
echo "========================================"
echo "Dragonwilds update completed"
echo "========================================"
echo "Running build: $NEW_INSTALLED_MANIFEST"

notify \
    "Dragonwilds update successful" \
    "The server update completed successfully.
Previous manifest: $INSTALLED_MANIFEST
Installed manifest: $NEW_INSTALLED_MANIFEST
Manifest verification: passed
Server service: running"

exit 0
