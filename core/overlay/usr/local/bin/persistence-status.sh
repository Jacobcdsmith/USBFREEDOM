#!/bin/bash
# USBFREEDOM Persistence Status Checker
# Displays current persistence status and information

PERSIST_LABEL="persistence"
PERSIST_MOUNT="/persistence"

echo "╔═══════════════════════════════════════════════════════════╗"
echo "║        USBFREEDOM Persistence Status                     ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo

# Check for persistence partition
PERSIST_PART=$(findfs LABEL=$PERSIST_LABEL 2>/dev/null || true)

if [[ -z "$PERSIST_PART" ]]; then
    echo "❌ Persistence: NOT AVAILABLE"
    echo "   No partition found with label '$PERSIST_LABEL'"
    exit 1
fi

echo "✓ Persistence Partition: $PERSIST_PART"

# Check if mounted
if mountpoint -q "$PERSIST_MOUNT" 2>/dev/null; then
    echo "✓ Status: ACTIVE (mounted at $PERSIST_MOUNT)"
    echo

    # Display usage information
    echo "Disk Usage:"
    df -h "$PERSIST_MOUNT" | tail -1 | awk '{printf "  Total: %s\n  Used: %s (%s)\n  Available: %s\n", $2, $3, $5, $4}'
    echo

    # Check for persistence.conf
    if [[ -f "$PERSIST_MOUNT/persistence.conf" ]]; then
        echo "✓ Configuration: Found"
        echo
        echo "Persisted Paths:"
        grep -v '^#' "$PERSIST_MOUNT/persistence.conf" | grep -v '^$' | while read -r line; do
            echo "  • $line"
        done
    else
        echo "⚠ Configuration: Missing (persistence.conf not found)"
    fi

    echo

    # List top-level contents
    echo "Persistence Contents:"
    ls -lh "$PERSIST_MOUNT" | tail -n +2 | awk '{printf "  %s  %5s  %s\n", $1, $5, $9}'

else
    echo "○ Status: INACTIVE (not mounted)"
    echo "   Run 'sudo enable-persistence.sh' to activate"
fi

echo
echo "Commands:"
echo "  enable-persistence.sh   - Mount and enable persistence"
echo "  disable-persistence.sh  - Safely unmount persistence"
echo "  backup-persistence.sh   - Backup persistence data"

exit 0
