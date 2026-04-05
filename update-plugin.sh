#!/usr/bin/env bash
set -euo pipefail

# update-plugin.sh — Install or update the clawdance plugin.
# Usage: ./update-plugin.sh
# After running, use /reload-plugins in Claude Code to pick up changes.

MARKETPLACE="clawdance-marketplace"
PLUGIN="clawdance@${MARKETPLACE}"
PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)/plugin"

# Determine settings.json path (respect CLAUDE_CONFIG_DIR)
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SETTINGS="$CLAUDE_DIR/settings.json"

echo "=== clawdance installer ==="
echo ""

# --- Plugin installation ---
echo "Installing plugin..."
claude plugin marketplace update "$MARKETPLACE" 2>/dev/null || {
  echo "  Marketplace not found. Registering..."
  claude plugin marketplace add "$MARKETPLACE" "$PLUGIN_DIR"
}

claude plugin uninstall "$PLUGIN" 2>/dev/null || true
claude plugin install "$PLUGIN"
echo "  Plugin installed."

# --- PreCompact hook ---
echo ""
echo "Checking PreCompact hook..."

HOOK_CMD="touch .clawdance/compact-signal"

if [ -f "$SETTINGS" ]; then
  # Check if our hook already exists
  if python3 -c "
import json, sys
with open('$SETTINGS') as f: d = json.load(f)
hooks = d.get('hooks', {}).get('PreCompact', [])
for h in hooks:
    items = h.get('hooks', [h])
    for item in items:
        if item.get('command','') == '$HOOK_CMD':
            sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
    echo "  PreCompact hook already configured."
  else
    # Add the hook
    python3 -c "
import json
with open('$SETTINGS') as f: d = json.load(f)
hooks = d.setdefault('hooks', {})
pre_compact = hooks.setdefault('PreCompact', [])
pre_compact.append({'hooks': [{'type': 'command', 'command': '$HOOK_CMD', 'timeout': 5}]})
with open('$SETTINGS', 'w') as f: json.dump(d, f, indent=2)
print('  PreCompact hook added to $SETTINGS')
"
  fi
else
  echo "  No settings.json found at $SETTINGS"
  echo "  Creating with PreCompact hook..."
  mkdir -p "$CLAUDE_DIR"
  cat > "$SETTINGS" << 'SETTINGSEOF'
{
  "hooks": {
    "PreCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "touch .clawdance/compact-signal",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
SETTINGSEOF
  echo "  Created $SETTINGS with PreCompact hook."
fi

echo ""
echo "Done. Run /reload-plugins in Claude Code to activate."
echo "Then use /clawdance-setup in your project to get started."
