#!/usr/bin/env bash
set -euo pipefail

# update-plugin.sh — Install or update the clawdance plugin.
# Usage: ./update-plugin.sh
# After running, use /reload-plugins in Claude Code to pick up changes.

MARKETPLACE="clawdance-marketplace"
GITHUB_REPO="Gunther-Schulz/clawdance"
PLUGIN="clawdance@${MARKETPLACE}"

echo "=== clawdance installer ==="
echo ""

# Register or update marketplace
if claude plugin marketplace list 2>/dev/null | grep -q "$MARKETPLACE"; then
  echo "Updating marketplace..."
  claude plugin marketplace update "$MARKETPLACE"
else
  echo "Registering marketplace..."
  claude plugin marketplace add "$GITHUB_REPO"
fi

# Install plugin
echo "Installing plugin..."
claude plugin uninstall "$PLUGIN" 2>/dev/null || true
claude plugin install "$PLUGIN"

echo ""
echo "Done. Run /reload-plugins in Claude Code to activate."
echo "Then use /clawdance in your project to get started."
