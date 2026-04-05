#!/usr/bin/env bash
set -euo pipefail

# update-plugin.sh — Update the installed clawdance plugin after changes.
# Usage: ./update-plugin.sh
# After running, use /reload-plugins in Claude Code to pick up changes.

MARKETPLACE="clawdance-marketplace"
PLUGIN="clawdance@${MARKETPLACE}"

echo "Updating clawdance marketplace..."
claude plugin marketplace update "$MARKETPLACE" 2>/dev/null || {
  echo "Marketplace not found. Registering..."
  claude plugin marketplace add "$MARKETPLACE" "$(cd "$(dirname "$0")" && pwd)/plugin"
}

echo "Reinstalling plugin..."
claude plugin uninstall "$PLUGIN" 2>/dev/null || true
claude plugin install "$PLUGIN"

echo ""
echo "Done. Run /reload-plugins in Claude Code to activate."
