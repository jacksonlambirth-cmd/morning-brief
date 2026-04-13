#!/bin/bash
# publish-brief.sh — Copy a new morning briefing into the dashboard and update manifest.json
#
# Usage:
#   ./publish-brief.sh /path/to/Morning-Brief-2026-04-14.html
#
# This script:
#   1. Extracts the date from the filename
#   2. Copies the HTML into briefs/
#   3. Updates manifest.json with the new entry
#   4. Commits and pushes to GitHub (which auto-deploys via GitHub Pages)

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BRIEFS_DIR="$SCRIPT_DIR/briefs"
MANIFEST="$SCRIPT_DIR/manifest.json"

if [ -z "$1" ]; then
  echo "Usage: ./publish-brief.sh /path/to/Morning-Brief-YYYY-MM-DD.html"
  exit 1
fi

SOURCE_FILE="$1"

if [ ! -f "$SOURCE_FILE" ]; then
  echo "Error: File not found: $SOURCE_FILE"
  exit 1
fi

# Extract date from filename (expects Morning-Brief-YYYY-MM-DD.html)
FILENAME=$(basename "$SOURCE_FILE")
DATE=$(echo "$FILENAME" | grep -oP '\d{4}-\d{2}-\d{2}')

if [ -z "$DATE" ]; then
  echo "Error: Could not extract date from filename. Expected format: Morning-Brief-YYYY-MM-DD.html"
  exit 1
fi

# Generate a human-readable label
LABEL=$(date -d "$DATE" '+%A, %B %-d, %Y' 2>/dev/null || date -j -f '%Y-%m-%d' "$DATE" '+%A, %B %-d, %Y' 2>/dev/null || echo "$DATE")

# Copy the file
DEST="$BRIEFS_DIR/$DATE.html"
cp "$SOURCE_FILE" "$DEST"
echo "Copied briefing to $DEST"

# Update manifest.json using Python (available on Mac and Linux)
python3 << PYEOF
import json, os

manifest_path = "$MANIFEST"
new_entry = {
    "date": "$DATE",
    "file": "briefs/$DATE.html",
    "label": "$LABEL"
}

if os.path.exists(manifest_path):
    with open(manifest_path, 'r') as f:
        data = json.load(f)
else:
    data = {"briefings": []}

# Remove existing entry for same date (if re-publishing)
data["briefings"] = [b for b in data["briefings"] if b["date"] != "$DATE"]

# Add new entry and sort newest first
data["briefings"].append(new_entry)
data["briefings"].sort(key=lambda x: x["date"], reverse=True)

with open(manifest_path, 'w') as f:
    json.dump(data, f, indent=2)

print(f"Updated manifest.json — now tracking {len(data['briefings'])} briefing(s)")
PYEOF

# Git commit and push (if in a git repo)
if [ -d "$SCRIPT_DIR/.git" ]; then
  cd "$SCRIPT_DIR"
  git add briefs/$DATE.html manifest.json
  git commit -m "Add morning brief for $DATE"
  git push origin main
  echo "Pushed to GitHub — site will update in ~60 seconds"
else
  echo "Not a git repo — skipping push. Copy these files to your hosting manually."
fi

echo "Done! Briefing for $DATE is published."
