#!/usr/bin/env bash
set -euo pipefail

# clawdance-loop.sh — Session lifecycle loop.
# Spawns tmux sessions with Claude Code, monitors for death, checks state,
# restarts. Keeps the build alive across session boundaries.
#
# Usage: clawdance-loop.sh [project-dir]
#
# Environment:
#   CLAWDANCE_MAX_FAILURES  — max consecutive unproductive sessions (default: 3)
#   CLAWDANCE_TELEGRAM_TOKEN — Telegram bot token (optional)
#   CLAWDANCE_TELEGRAM_CHAT  — Telegram chat ID (optional)
#
# Prerequisites: tmux, yq, claude (Claude Code CLI)

PROJECT_DIR="${1:-.}"
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
STATE_FILE="$PROJECT_DIR/.clawdance/state.yaml"
MAX_FAILURES="${CLAWDANCE_MAX_FAILURES:-3}"
TELEGRAM_TOKEN="${CLAWDANCE_TELEGRAM_TOKEN:-}"
TELEGRAM_CHAT="${CLAWDANCE_TELEGRAM_CHAT:-}"

if [ ! -f "$STATE_FILE" ]; then
  echo "Error: $STATE_FILE not found. Run /clawdance-decompose first."
  exit 1
fi

notify() {
  local msg="[clawdance] $1"
  echo "$msg"
  [ -n "$TELEGRAM_TOKEN" ] && [ -n "$TELEGRAM_CHAT" ] && curl -s \
    "https://api.telegram.org/bot$TELEGRAM_TOKEN/sendMessage" \
    -d "chat_id=$TELEGRAM_CHAT" -d "text=$msg" >/dev/null || true
}

LAST_CHECKPOINT=""

while true; do
  status=$(yq -r '.status' "$STATE_FILE")
  failures=$(yq -r '.consecutive_failures // 0' "$STATE_FILE")

  case "$status" in
    completed)
      notify "Build completed."
      exit 0
      ;;
    failed)
      notify "Build failed. Check .clawdance/state.yaml for details."
      exit 1
      ;;
  esac

  if [ "$failures" -ge "$MAX_FAILURES" ]; then
    notify "Backed off after $failures consecutive unproductive sessions."
    exit 2
  fi

  # Rate-limit-aware delay after unproductive sessions
  if [ "$failures" -gt 0 ]; then
    delay=$((30 * failures))
    notify "Waiting ${delay}s before retry ($failures/$MAX_FAILURES)"
    sleep "$delay"
  fi

  SESSION="clawdance-$(date +%s)"
  notify "Starting session $SESSION"

  tmux new-session -d -s "$SESSION" -c "$PROJECT_DIR"
  tmux send-keys -t "$SESSION" -l 'claude "/clawdance resume"'
  tmux send-keys -t "$SESSION" Enter

  # Wait for session to end
  while tmux has-session -t "$SESSION" 2>/dev/null; do
    sleep 10
  done

  # Check if session was productive (new checkpoint written)
  new_checkpoint=$(yq -r '.last_checkpoint_at // ""' "$STATE_FILE")
  if [ "$new_checkpoint" = "$LAST_CHECKPOINT" ]; then
    # No progress — likely rate limit, crash, or context exhaustion
    current=$(yq -r '.consecutive_failures // 0' "$STATE_FILE")
    yq -i ".consecutive_failures = $((current + 1))" "$STATE_FILE"
    notify "Session $SESSION ended without progress (failure $((current + 1))/$MAX_FAILURES)"
  else
    notify "Session $SESSION completed with progress"
  fi
  LAST_CHECKPOINT="$new_checkpoint"
done
