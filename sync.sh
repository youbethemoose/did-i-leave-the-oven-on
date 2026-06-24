#!/bin/bash

# ─────────────────────────────────────────────────────
# Did I Leave the Oven On — Folder Sync App
# Pure osascript — no Python, no tkinter, guaranteed to work
# ─────────────────────────────────────────────────────

CONFIG_DIR="$HOME/.config/did-i-leave-the-oven-on"
CONFIG_FILE="$CONFIG_DIR/config"
mkdir -p "$CONFIG_DIR"

# ── Load saved folders ──
SAVED_SOURCE=""
SAVED_DEST=""
if [ -f "$CONFIG_FILE" ]; then
    SAVED_SOURCE=$(grep '^SOURCE=' "$CONFIG_FILE" | cut -d= -f2-)
    SAVED_DEST=$(grep '^DEST=' "$CONFIG_FILE" | cut -d= -f2-)
fi

# ── Step 1: Pick folders (or use saved) ──
if [ -n "$SAVED_SOURCE" ] && [ -n "$SAVED_DEST" ] && [ -d "$SAVED_SOURCE" ]; then
    SAVED_FOLDER_NAME=$(basename "$SAVED_SOURCE")

    # Check if destination is mounted
    if [ ! -d "$SAVED_DEST" ]; then
        osascript -e "display notification \"Saved destination not found — please pick a new one\" with title \"Did I Leave the Oven On\""
        PICK_NEW=1
    else
        CHOICE=$(osascript -e "button returned of (display dialog \"Ready to sync:

Folder:      $SAVED_FOLDER_NAME
Destination: $SAVED_DEST

New and updated files only. Unchanged files skipped.\" buttons {\"Change\", \"Sync\"} default button \"Sync\")" 2>/dev/null)

        if [ "$CHOICE" = "Sync" ]; then
            SOURCE="$SAVED_SOURCE"
            DEST="$SAVED_DEST"
            PICK_NEW=0
        else
            PICK_NEW=1
        fi
    fi
else
    PICK_NEW=1
fi

# ── Pick new folders if needed ──
if [ "$PICK_NEW" -eq 1 ]; then
    SOURCE=$(osascript -e 'tell application "Finder"
        set sourceFolder to choose folder with prompt "Select the folder you want to back up:"
        return POSIX path of sourceFolder
    end tell' 2>/dev/null)

    if [ -z "$SOURCE" ]; then exit 0; fi
    SOURCE="${SOURCE%/}"

    DEST=$(osascript -e 'tell application "Finder"
        set destFolder to choose folder with prompt "Select the destination (where the folder will be placed):"
        return POSIX path of destFolder
    end tell' 2>/dev/null)

    if [ -z "$DEST" ]; then exit 0; fi
    DEST="${DEST%/}"

    # Save for next time
    echo "SOURCE=$SOURCE" > "$CONFIG_FILE"
    echo "DEST=$DEST" >> "$CONFIG_FILE"

    FOLDER_NAME=$(basename "$SOURCE")

    CONFIRM=$(osascript -e "button returned of (display dialog \"Ready to sync:

Folder:      $FOLDER_NAME
Destination: $DEST

New and updated files only. Unchanged files skipped.\" buttons {\"Cancel\", \"Sync\"} default button \"Sync\")" 2>/dev/null)

    if [ "$CONFIRM" != "Sync" ]; then exit 0; fi
fi

FOLDER_NAME=$(basename "$SOURCE")

# ── Count total files ──
TOTAL_FILES=$(find "$SOURCE" -type f | wc -l | tr -d ' ')

if [ "$TOTAL_FILES" -eq 0 ]; then
    osascript -e 'display alert "Empty Folder" message "The source folder appears to be empty. Nothing to sync."'
    exit 0
fi

# ── Run rsync with progress tracking ──
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

# ── Flush write buffers ──
sync

# ── Verify ──
VERIFY_OUTPUT=$(rsync -a --dry-run --itemize-changes --modify-window=2 "$SOURCE/" "$DEST_FOLDER/" 2>&1)
MISMATCHES=$(echo "$VERIFY_OUTPUT" | grep -cE '^>f|^<f')
DEST_COUNT=$(find "$DEST_FOLDER" -type f | wc -l | tr -d ' ')

# ── Show result ──
if [ "$MISMATCHES" -gt 0 ]; then
    osascript -e "display alert \"⚠️ Verification Failed\" message \"$MISMATCHES file(s) don't match the source. Try running again.\""
else
    osascript -e "display alert \"✅ Sync Complete & Verified\" message \"All $DEST_COUNT files synced and verified 1:1.

$FOLDER_NAME → $DEST

Safe to eject your drive.\""
fi
