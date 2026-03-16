#!/usr/bin/env bash
# Chromium kiosk launcher for Raffle Entry Collector
# Waits for Rails to be ready, then launches Chromium in kiosk mode.
# Runs in a loop to recover from Chromium crashes.

set -euo pipefail

RAILS_URL="http://127.0.0.1:3000"
HEALTH_TIMEOUT=60

wait_for_rails() {
    local elapsed=0
    echo "Waiting for Rails at ${RAILS_URL}..."
    while [ $elapsed -lt $HEALTH_TIMEOUT ]; do
        if curl --silent --fail "${RAILS_URL}" > /dev/null 2>&1; then
            echo "Rails is ready."
            return 0
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done
    echo "ERROR: Rails did not become ready within ${HEALTH_TIMEOUT}s"
    return 1
}

while true; do
    if wait_for_rails; then
        chromium \
            --kiosk \
            --ozone-platform=wayland \
            --noerrdialogs \
            --disable-translate \
            --disable-features=TranslateUI \
            --no-first-run \
            --disable-infobars \
            --disable-session-crashed-bubble \
            --disable-component-update \
            --check-for-update-interval=31536000 \
            --autoplay-policy=no-user-gesture-required \
            --password-store=basic \
            "${RAILS_URL}" || true
    fi

    echo "Chromium exited. Restarting in 2 seconds..."
    sleep 2
done
