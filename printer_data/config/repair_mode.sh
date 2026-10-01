#!/bin/bash
# ---------------------------------------------------------------------------
# Toolhead REPAIR MODE switch for the SV08.
#
#   repair_mode.sh ON    -> Klipper loads printer_REPAIR.cfg (mainboard + lights only)
#   repair_mode.sh OFF   -> Klipper loads printer.cfg (normal)
#   repair_mode.sh STATUS
#
# Klipper refuses to start if ANY configured MCU is missing, so with the
# toolhead board unplugged printer.cfg can never come up and the mainboard
# never turns the chamber light on. Repair mode doesn't edit printer.cfg at
# all: it changes which file the klipper service loads (KLIPPER_ARGS in
# klipper.env), so printer.cfg / SAVE_CONFIG / the MMX variants stay as-is.
# The setting survives a power cycle until you switch it back.
# ---------------------------------------------------------------------------
set -euo pipefail

CFG="$HOME/printer_data/config"
ENV="$HOME/printer_data/systemd/klipper.env"
NORMAL="$CFG/printer.cfg"
REPAIR="$CFG/printer_REPAIR.cfg"

case "${1:-}" in
    ON)  FROM="$NORMAL"; TO="$REPAIR" ;;
    OFF) FROM="$REPAIR"; TO="$NORMAL" ;;
    STATUS)
        grep -q "$REPAIR" "$ENV" && echo "REPAIR MODE is ON" || echo "REPAIR MODE is OFF (normal printer.cfg)"
        exit 0 ;;
    *) echo "usage: repair_mode.sh ON|OFF|STATUS" >&2; exit 1 ;;
esac

[ -f "$TO" ] || { echo "ERROR: missing $TO" >&2; exit 1; }

if grep -q " $TO " "$ENV"; then
    echo "Already set to load $(basename "$TO") - restarting Klipper anyway"
else
    grep -q " $FROM " "$ENV" || { echo "ERROR: $ENV doesn't reference $(basename "$FROM"); not touching it" >&2; exit 1; }
    cp -p "$ENV" "$ENV.bak"
    sed -i "s| $FROM | $TO |" "$ENV"
    sync
    echo "klipper.env now loads $(basename "$TO")"
fi

# --no-block: queue the restart and return immediately. This script runs as a
# child of klippy, so it gets killed when the service stops.
if ! sudo -n systemctl --no-block restart klipper 2>/dev/null; then
    curl -s -m 5 -X POST "http://localhost:7125/machine/services/restart?service=klipper" >/dev/null &
fi
echo "Klipper restarting..."
