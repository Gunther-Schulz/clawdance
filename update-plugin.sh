#!/usr/bin/env bash
set -euo pipefail

# update-plugin.sh — Update the installed clawdance plugin after pushing changes.
# Usage: ./update-plugin.sh
# After running, use /reload-plugins in Claude Code to pick up changes.
#
# First-time install (run inside Claude Code):
#   /plugin marketplace add Gunther-Schulz/clawdance
#   /plugin install clawdance@clawdance-marketplace
#   /reload-plugins

echo "Updating clawdance marketplace..."
claude plugin marketplace update clawdance-marketplace

echo "Reinstalling plugin..."
claude plugin uninstall clawdance@clawdance-marketplace
claude plugin install clawdance@clawdance-marketplace

echo ""
echo "Done. Run /reload-plugins in Claude Code to activate."
