#!/bin/bash

# ─────────────────────────────────────────────────────
# Did I Leave the Oven On — Folder Sync App
# Pure osascript — no Python, no tkinter, guaranteed to work
# ─────────────────────────────────────────────────────

# ── Step 1: Pick SOURCE folder ──
SOURCE=$(osascript -e 'tell application "Finder"
    set sourceFolder to choose folder with prompt "Select the folder you want to back up:"
    return POSIX path of sourceFolder
end tell' 2>/dev/null)

if [ -z "$SOURCE" ]; then
    exit 0
fi

SOURCE="${SOURCE%/}"
FOLDER_NAME=$(basename "$SOURCE")

# ── Step 2: Pick DESTINATION ──
DEST=$(osascript -e 'tell application "Finder"
    set destFolder to choose folder with prompt "Select the destination (where the folder will be placed):"
    return POSIX path of destFolder
end tell' 2>/dev/null)

if [ -z "$DEST" ]; then
    exit 0
fi

DEST="${DEST%/}"

# ── Step 3: Confirm ──
CONFIRM=$(osascript -e "button returned of (display dialog \"Ready to sync:

Folder:      $FOLDER_NAME
Destination: $DEST

New and updated files only. Unchanged files skipped.\" buttons {\"Cancel\", \"Sync\"} default button \"Sync\")" 2>/dev/null)

if [ "$CONFIRM" != "Sync" ]; then
    exit 0
fi

# ── Step 4: Count total files ──
TOTAL_FILES=$(find "$SOURCE" -type f | wc -l | tr -d ' ')

if [ "$TOTAL_FILES" -eq 0 ]; then
    osascript -e 'display alert "Empty Folder" message "The source folder appears to be empty. Nothing to sync."'
    exit 0
fi

# ── Step 5: Run rsync with progress tracking ──
ERRFILE=$(mktemp)
trap 'rm -f "$ERRFILE"' EXIT

DEST_FOLDER="$DEST/$(basename "$SOURCE")"

HALFWAY=$((TOTAL_FILES / 2))
HALFWAY_NOTIFIED=0

rsync -a --update --modify-window=2 "$SOURCE" "$DEST" 2>"$ERRFILE" &
RSYNC_PID=$!

while kill -0 "$RSYNC_PID" 2>/dev/null; do
    sleep 3
    if [ "$HALFWAY_NOTIFIED" -eq 0 ] && [ -d "$DEST_FOLDER" ]; then
        DONE=$(find "$DEST_FOLDER" -type f | wc -l | tr -d ' ')
        if [ "$DONE" -ge "$HALFWAY" ]; then
            osascript -e "display notification \"Halfway there — still syncing…\" with title \"Did I Leave the Oven On\" subtitle \"$FOLDER_NAME\""
            HALFWAY_NOTIFIED=1
        fi
    fi
done

wait "$RSYNC_PID"
RSYNC_EXIT=$?

if [ "$RSYNC_EXIT" -ne 0 ]; then
    osascript -e 'display alert "Sync Failed" message "rsync encountered an error. Please check the source and destination and try again."'
    exit 1
fi

# ── Step 6: Flush write buffers ──
sync

# ── Step 7: Verify ──
VERIFY_OUTPUT=$(rsync -a --dry-run --itemize-changes --modify-window=2 "$SOURCE/" "$DEST_FOLDER/" 2>&1)
MISMATCHES=$(echo "$VERIFY_OUTPUT" | grep -cE '^>f|^<f')
DEST_COUNT=$(find "$DEST_FOLDER" -type f | wc -l | tr -d ' ')

# ── Step 8: Show result ──
if [ "$MISMATCHES" -gt 0 ]; then
    osascript -e "display alert \"⚠️ Verification Failed\" message \"$MISMATCHES file(s) don't match the source. Try running again.\""
else
    osascript -e "display alert \"✅ Sync Complete & Verified\" message \"All $DEST_COUNT files synced and verified 1:1.

$FOLDER_NAME → $DEST

Safe to eject your drive.\""
fi
