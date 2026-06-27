#!/bin/bash
set -e

DEST="$HOME/.claude"
SETTINGS="$DEST/settings.json"

echo "Installing claude-code-statusline..."

# Copy script
cp statusline.sh "$DEST/statusline.sh"
chmod +x "$DEST/statusline.sh"
echo "  Copied statusline.sh to $DEST/"

# Update settings.json
if [ ! -f "$SETTINGS" ]; then
    echo '{}' > "$SETTINGS"
fi

if command -v jq &>/dev/null; then
    tmp=$(mktemp)
    jq '. + {"statusLine": {"type": "command", "command": "~/.claude/statusline.sh"}}' "$SETTINGS" > "$tmp"
    mv "$tmp" "$SETTINGS"
    echo "  Updated $SETTINGS"
else
    echo ""
    echo "  jq not found. Please add the following to $SETTINGS manually:"
    echo '  "statusLine": {"type": "command", "command": "~/.claude/statusline.sh"}'
fi

echo ""
echo "Done. Restart Claude Code to apply."

# Windows note
if [[ "$OSTYPE" == "msys"* ]] || [[ "$OSTYPE" == "cygwin"* ]]; then
    echo ""
    echo "Windows users: copy statusline.ps1 to %USERPROFILE%\\.claude\\ and"
    echo "set the command to: powershell -NoProfile -File ~/.claude/statusline.ps1"
fi
