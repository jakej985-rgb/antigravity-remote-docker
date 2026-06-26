#!/usr/bin/env bash
# =============================================================================
# Antigravity Remote Docker - Autostart
# =============================================================================
#
# Purpose:
#   Automatically launch Antigravity IDE after the XFCE desktop starts.
#
# Startup Order:
#   1. Wait for XFCE and X11 to initialize.
#   2. Verify Antigravity IDE is installed.
#   3. Launch the IDE.
#   4. Wait for the application window.
#   5. Maximize the window for a kiosk-like experience.
#
# Notes:
#   - Runs as the non-root 'antigravity' user.
#   - Logs startup events to ~/.antigravity/autostart.log.
#   - Safe to run multiple times.
#   - Window title matching may need updating if Google changes it.
# =============================================================================

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================
LOG_DIR="$HOME/.antigravity"
LOG_FILE="$LOG_DIR/autostart.log"

# Time (seconds) to wait for the XFCE desktop.
STARTUP_DELAY=5

# Time (seconds) to wait after launching the IDE before attempting
# to find and maximize its window.
WINDOW_DELAY=5

# Possible window titles. Google may rename the application.
WINDOW_TITLES=(
    "Antigravity"
    "Antigravity IDE"
    "Google Antigravity"
    "antigravity-ide"
    "antigravity"
)

# =============================================================================
# Logging
# =============================================================================
mkdir -p "$LOG_DIR"

log() {
    echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"
}

log "=========================================="
log "Antigravity IDE Autostart"
log "=========================================="

# =============================================================================
# Wait for XFCE Desktop
# =============================================================================
log "Waiting ${STARTUP_DELAY}s for XFCE..."
sleep "$STARTUP_DELAY"

# Wait until an X display is available.
log "Waiting for X11 display..."
until xdpyinfo >/dev/null 2>&1; do
    sleep 1
done

log "Display detected."

# =============================================================================
# Verify Installation
# =============================================================================
if ! command -v antigravity-ide >/dev/null 2>&1; then
    log "ERROR: antigravity-ide not found in PATH."
    log "PATH=$PATH"
    exit 1
fi

log "Found antigravity-ide."

# =============================================================================
# Launch IDE
# =============================================================================
log "Launching Antigravity IDE..."

antigravity-ide >>"$LOG_FILE" 2>&1 &

PID=$!

log "Started with PID ${PID}"

# =============================================================================
# Wait for Window Creation
# =============================================================================
sleep "$WINDOW_DELAY"

# =============================================================================
# Maximize Window
# =============================================================================
log "Searching for application window..."

FOUND=false

for TITLE in "${WINDOW_TITLES[@]}"; do

    if command -v xdotool >/dev/null 2>&1; then
        WINDOW=$(xdotool search --name "$TITLE" 2>/dev/null | head -1 || true)

        if [ -n "$WINDOW" ]; then

            log "Found window '$TITLE' ($WINDOW)"

            xdotool windowactivate "$WINDOW" 2>/dev/null || true
            xdotool windowsize "$WINDOW" 100% 100% 2>/dev/null || true
            xdotool windowmove "$WINDOW" 0 0 2>/dev/null || true

            FOUND=true
            break
        fi
    fi

    if command -v wmctrl >/dev/null 2>&1; then
        wmctrl -r "$TITLE" -b add,maximized_vert,maximized_horz 2>/dev/null || true
    fi

done

if [ "$FOUND" = true ]; then
    log "Window maximized."
else
    log "WARNING: No matching window found."
    log "The IDE may still be starting or the window title has changed."
fi

log "Autostart complete."
