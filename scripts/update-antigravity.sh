#!/bin/bash
# =============================================================================
# Antigravity Docker - Auto-Update Script
# =============================================================================
# Checks for and installs the latest Antigravity IDE via official tarball.
# No apt/keyring required. Compares installed version against the latest
# release manifest and performs an in-place upgrade if a newer version exists.
# =============================================================================

set -e

LOG_FILE="/tmp/antigravity-update.log"
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

ANTIGRAVITY_HOME="${ANTIGRAVITY_HOME:-/opt/antigravity-ide}"
BINARY="${ANTIGRAVITY_HOME}/antigravity-ide"
# Use explicit owner instead of $USER which can be unset in supervisor context
ANTIGRAVITY_OWNER="${USER:-$(whoami)}"

# Latest release manifest endpoint (returns redirect to current tarball)
RELEASE_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/latest/linux-x64/Antigravity%20IDE.tar.gz"
VERSION_URL="https://edgedl.me.gvt1.com/edgedl/release2/j0qc3/antigravity/stable/latest/linux-x64/version"

log() {
    echo "[${TIMESTAMP}] $1" | tee -a "${LOG_FILE}"
}

log "============================================"
log "Checking for Antigravity updates..."
log "============================================"

# =============================================================================
# Get currently installed version
# =============================================================================
if [ -f "${BINARY}" ]; then
    CURRENT_VERSION=$("${BINARY}" --version 2>/dev/null | head -1 | grep -oP '[\d.]+' | head -1 || echo "unknown")
else
    CURRENT_VERSION="not-installed"
fi
log "Current version: ${CURRENT_VERSION}"

# =============================================================================
# Get latest available version from manifest
# =============================================================================
log "Fetching latest version info..."
CANDIDATE_VERSION=$(curl -fsSL --max-time 15 "${VERSION_URL}" 2>/dev/null | tr -d '[:space:]' || echo "")

if [ -z "${CANDIDATE_VERSION}" ]; then
    log "Warning: Could not fetch latest version info. Skipping update."
    exit 0
fi

log "Available version: ${CANDIDATE_VERSION}"

# =============================================================================
# Compare and upgrade if needed
# =============================================================================
if [ "${CURRENT_VERSION}" = "${CANDIDATE_VERSION}" ]; then
    log "Antigravity IDE is already up to date (${CURRENT_VERSION})."
    log "Update check complete."
    log "============================================"
    exit 0
fi

log "New version available (${CURRENT_VERSION} -> ${CANDIDATE_VERSION}). Downloading..."

TMPFILE=$(mktemp /tmp/antigravity-update-XXXXXX.tar.gz)

if ! curl -fsSL --max-time 300 "${RELEASE_URL}" -o "${TMPFILE}"; then
    log "Warning: Failed to download tarball. Skipping update."
    rm -f "${TMPFILE}"
    exit 0
fi

log "Download complete. Installing..."

# Replace the existing installation in-place
sudo tar -xzf "${TMPFILE}" -C "${ANTIGRAVITY_HOME}" --strip-components=1
sudo chmod +x "${BINARY}"
sudo chown -R "${ANTIGRAVITY_OWNER}:${ANTIGRAVITY_OWNER}" "${ANTIGRAVITY_HOME}"

rm -f "${TMPFILE}"

NEW_VERSION=$("${BINARY}" --version 2>/dev/null | head -1 | grep -oP '[\d.]+' | head -1 || echo "unknown")
log "Successfully upgraded to version: ${NEW_VERSION}"

# Notify desktop user if possible
if command -v notify-send &>/dev/null && [ -n "${DISPLAY:-}" ]; then
    notify-send "Antigravity Updated" "Updated to version ${NEW_VERSION}" --icon=system-software-update 2>/dev/null || true
fi

log "Update check complete."
log "============================================"
