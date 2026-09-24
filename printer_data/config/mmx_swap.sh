#!/bin/bash
# ---------------------------------------------------------------------------
# Swap the SV08 between MMX-enabled and single-filament Klipper configs.
#
#   mmx_swap.sh ENABLED    -> Happy Hare + MMX (requires MMX powered on)
#   mmx_swap.sh DISABLED   -> single filament, no [mcu mmu] (MMX may be off)
#
# Klipper only ever loads printer.cfg, so swapping means copying one of the
# two variants over it. Before switching, the CURRENT printer.cfg is written
# back over its own variant file -- this preserves anything Klipper's
# SAVE_CONFIG appended (bed mesh, probe offsets, input shaper) while you were
# in that mode. Without that write-back those values would be silently lost
# on every swap.
# ---------------------------------------------------------------------------
set -euo pipefail

CFG="$HOME/printer_data/config"
TARGET="${1:-}"

case "$TARGET" in
    ENABLED|DISABLED) ;;
    *) echo "usage: mmx_swap.sh ENABLED|DISABLED" >&2; exit 1 ;;
esac

for f in printer.cfg printer_MMX_ENABLED.cfg printer_MMX_DISABLED.cfg; do
    [ -f "$CFG/$f" ] || { echo "ERROR: missing $CFG/$f" >&2; exit 1; }
done

# Which variant is live right now? The MMU include is the discriminator.
if grep -qE '^\[include mmu/base/\*\.cfg\]' "$CFG/printer.cfg"; then
    CURRENT=ENABLED
else
    CURRENT=DISABLED
fi

# Preserve SAVE_CONFIG edits made while in the current mode
cp "$CFG/printer.cfg" "$CFG/printer_MMX_${CURRENT}.cfg"

if [ "$CURRENT" = "$TARGET" ]; then
    echo "Already in ${TARGET} mode. Current state written back to printer_MMX_${TARGET}.cfg"
    exit 0
fi

cp "$CFG/printer_MMX_${TARGET}.cfg" "$CFG/printer.cfg"
echo "Switched ${CURRENT} -> ${TARGET}"
