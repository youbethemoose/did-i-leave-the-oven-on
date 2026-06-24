#!/bin/bash

# ─────────────────────────────────────────────────────
# Did I Leave the Oven On — Folder Sync App
# Pure osascript — no Python, no tkinter, guaranteed to work
# ─────────────────────────────────────────────────────

CONFIG_DIR="$HOME/.config/did-i-leave-the-oven-on"
CONFIG_FILE="$CONFIG_DIR/config"
mkdir -p "$CONFIG_DIR"

# ── Load saved config ──
SAVED_SOURCES=()
SAVED_DEST=""
if [ -f "$CONFIG_FILE" ]; then
    while IFS= read -r line; do
        if [[ "$line" == SOURCE=* ]]; then
            SAVED_SOURCES+=("${line#SOURCE=}")
        elif [[ "$line" == DEST=* ]]; then
            SAVED_DEST="${line#DEST=}"
        fi
    done < "$CONFIG_FILE"
fi

PICK_NEW=1

if [ ${#SAVED_SOURCES[@]} -gt 0 ] && [ -n "$SAVED_DEST" ]; then
    ALL_EXIST=1
    for SRC in "${SAVED_SOURCES[@]}"; do
        [ ! -d "$SRC" ] && ALL_EXIST=0 && break
    done

    if [ "$ALL_EXIST" -eq 1 ]; then
        if [ ! -d "$SAVED_DEST" ]; then
            osascript -e "display notification \"Saved destination not found — please pick a new one\" with title \"Did I Leave the Oven On\""
            PICK_NEW=1
        else
            FOLDER_LIST=""
            for SRC in "${SAVED_SOURCES[@]}"; do
                FOLDER_LIST="${FOLDER_LIST}• $(basename "$SRC")
"
            done

            CHOICE=$(osascript -e "button returned of (display dialog \"Ready to sync to $(basename "$SAVED_DEST"):

${FOLDER_LIST}
New and updated files only. Unchanged files skipped.\" buttons {\"Change\", \"Sync\"} default button \"Sync\")" 2>/dev/null)

            if [ "$CHOICE" = "Sync" ]; then
                SOURCES=("${SAVED_SOURCES[@]}")
                DEST="$SAVED_DEST"
                PICK_NEW=0
            else
                PICK_NEW=1
            fi
        fi
    fi
fi

# ── Pick new folders if needed ──
if [ "$PICK_NEW" -eq 1 ]; then
    DEST=$(osascript -e 'tell application "Finder"
        set destFolder to choose folder with prompt "Select the destination drive or folder:"
        return POSIX path of destFolder
    end tell' 2>/dev/null)
    if [ -z "$DEST" ]; then exit 0; fi
    DEST="${DEST%/}"

    SOURCES=()
    while true; do
        SRC=$(osascript -e 'tell application "Finder"
            set sourceFolder to choose folder with prompt "Select a folder to back up:"
            return POSIX path of sourceFolder
        end tell' 2>/dev/null)
        if [ -z "$SRC" ]; then
            [ ${#SOURCES[@]} -eq 0 ] && exit 0
            break
        fi
        SOURCES+=("${SRC%/}")

        ANOTHER=$(osascript -e 'button returned of (display dialog "Add another folder to this backup?" buttons {"Done", "Add Another"} default button "Add Another")' 2>/dev/null)
        [ "$ANOTHER" = "Done" ] && break
    done

    # Save config
    > "$CONFIG_FILE"
    for SRC in "${SOURCES[@]}"; do
        echo "SOURCE=$SRC" >> "$CONFIG_FILE"
    done
    echo "DEST=$DEST" >> "$CONFIG_FILE"

    FOLDER_LIST=""
    for SRC in "${SOURCES[@]}"; do
        FOLDER_LIST="${FOLDER_LIST}• $(basename "$SRC")
"
    done

    CONFIRM=$(osascript -e "button returned of (display dialog \"Ready to sync ${#SOURCES[@]} folder(s) to $(basename "$DEST"):

${FOLDER_LIST}
New and updated files only. Unchanged files skipped.\" buttons {\"Cancel\", \"Sync\"} default button \"Sync\")" 2>/dev/null)
    [ "$CONFIRM" != "Sync" ] && exit 0
fi

# ── Count total files ──
TOTAL_FILES=0
for SRC in "${SOURCES[@]}"; do
    COUNT=$(find "$SRC" -type f | wc -l | tr -d ' ')
    TOTAL_FILES=$((TOTAL_FILES + COUNT))
done

if [ "$TOTAL_FILES" -eq 0 ]; then
    osascript -e 'display alert "Empty Folders" message "The selected folders appear to be empty. Nothing to sync."'
    exit 0
fi

# ── Prevent sleep ──
caffeinate -i &
CAFFEINATE_PID=$!

ERRFILE=$(mktemp)
trap 'rm -f "$ERRFILE"; kill $CAFFEINATE_PID 2>/dev/null' EXIT

HALFWAY=$((TOTAL_FILES / 2))
HALFWAY_NOTIFIED=0
TOTAL_DONE=0

# ── Sync each folder ──
for SRC in "${SOURCES[@]}"; do
    FOLDER_NAME=$(basename "$SRC")
    DEST_FOLDER="$DEST/$FOLDER_NAME"

    rsync -a --update --modify-window=2 "$SRC" "$DEST" 2>>"$ERRFILE" &
    RSYNC_PID=$!

    while kill -0 "$RSYNC_PID" 2>/dev/null; do
        sleep 3
        if [ "$HALFWAY_NOTIFIED" -eq 0 ] && [ -d "$DEST_FOLDER" ]; then
            DONE=$(find "$DEST_FOLDER" -type f | wc -l | tr -d ' ')
            if [ $((TOTAL_DONE + DONE)) -ge "$HALFWAY" ]; then
                osascript -e "display notification \"Halfway there — still syncing…\" with title \"Did I Leave the Oven On\""
                HALFWAY_NOTIFIED=1
            fi
        fi
    done

    wait "$RSYNC_PID"
    RSYNC_EXIT=$?

    if [ "$RSYNC_EXIT" -ne 0 ]; then
        osascript -e "display alert \"Sync Failed\" message \"rsync encountered an error syncing $FOLDER_NAME. Please check the source and destination and try again.\""
        exit 1
    fi

    TOTAL_DONE=$((TOTAL_DONE + $(find "$DEST_FOLDER" -type f | wc -l | tr -d ' ')))
done

kill $CAFFEINATE_PID 2>/dev/null

# ── Flush write buffers ──
sync

# ── Verify all folders ──
TOTAL_MISMATCHES=0
TOTAL_DEST_COUNT=0
FOLDER_LIST=""
for SRC in "${SOURCES[@]}"; do
    DEST_FOLDER="$DEST/$(basename "$SRC")"
    VERIFY=$(rsync -a --dry-run --itemize-changes --modify-window=2 "$SRC/" "$DEST_FOLDER/" 2>&1)
    MISMATCHES=$(echo "$VERIFY" | grep -cE '^>f|^<f')
    TOTAL_MISMATCHES=$((TOTAL_MISMATCHES + MISMATCHES))
    TOTAL_DEST_COUNT=$((TOTAL_DEST_COUNT + $(find "$DEST_FOLDER" -type f | wc -l | tr -d ' ')))
    FOLDER_LIST="${FOLDER_LIST}• $(basename "$SRC")
"
done

# ── Show result ──
if [ "$TOTAL_MISMATCHES" -gt 0 ]; then
    osascript -e "display alert \"⚠️ Verification Failed\" message \"$TOTAL_MISMATCHES file(s) don't match the source. Try running again.\""
else
    osascript -e "display alert \"✅ Sync Complete & Verified\" message \"All $TOTAL_DEST_COUNT files synced and verified 1:1.

${FOLDER_LIST}
→ $(basename "$DEST")

Safe to eject your drive.\""
fi
