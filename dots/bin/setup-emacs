#!/usr/bin/env bash

# Best Practice: Exit immediately if a command fails (-e), if an uninitialized
# variable is used (-u), and ensure pipeline failures are properly propagated (-o pipefail).
set -euo pipefail

# Define variables for paths, logging, and retry limits
EMACS_DIR="${HOME}/.config/emacs"
CONFIG_ORG="${EMACS_DIR}/config.org"
CONFIG_REPO="git@github.com:aahsnr-configs/minimal-emacs.git"
LOG_FILE="${EMACS_DIR}/emacs_setup_log.txt"
MAX_KILL_ATTEMPTS=5

# The final log file lives inside $EMACS_DIR, but that directory doesn't exist
# yet at script start (it's created fresh by the git clone below). So early
# messages are buffered to a temp file and merged into the real log once
# $EMACS_DIR exists.
LOG_BUFFER="$(mktemp "/tmp/emacs_setup_log.XXXXXX")"
CURRENT_LOG="$LOG_BUFFER"
trap 'rm -f "$LOG_BUFFER" 2>/dev/null || true' EXIT

# log <message>: prints to the console and appends a timestamped copy to
# whichever log target is currently active (buffer, then the real log file).
log() {
  local msg="$1"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "$msg"
  printf '[%s] %s\n' "$ts" "$msg" >>"$CURRENT_LOG"
}

# run_and_log <cmd...>: runs a command, streaming its combined stdout/stderr
# to the console in real time while also writing a timestamped copy of every
# line to the log file. Pipefail (set above) ensures the command's real exit
# status still propagates, so a failure here still aborts the script.
run_and_log() {
  "$@" 2>&1 | while IFS= read -r line; do
    printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$line" | tee -a "$CURRENT_LOG"
  done
}

log "=== Vanilla Emacs Initial Setup Script ==="
log "Run started: $(date '+%Y-%m-%d %H:%M:%S')"

# 1. Ensure the parent directory (~/.config) exists
mkdir -p "$(dirname "$EMACS_DIR")"

# 2. Verify required tools are available before doing anything else
for cmd in emacs emacsclient git; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    log "[✗] Error: '$cmd' was not found on PATH. Please install it first."
    exit 1
  fi
done

# 3. Find and remove any existing emacs config folder or symlink so we start
#    from a clean clone of the minimal-emacs configuration.
if [ -d "$EMACS_DIR" ] || [ -L "$EMACS_DIR" ]; then
  log "[*] Found an existing Emacs configuration directory at $EMACS_DIR."
  log "[*] Removing it safely..."
  rm -rf "$EMACS_DIR"
  log "[✓] Old configuration removed."
else
  log "[*] No existing Emacs configuration folder found. Proceeding cleanly..."
fi

# 4. Clone the vanilla (minimal-emacs) configuration repository.
log "[*] Cloning Emacs configuration repository..."
git clone "$CONFIG_REPO" "$EMACS_DIR"
log "[✓] Configuration cloned to $EMACS_DIR"

# 5. Now that $EMACS_DIR exists, move the buffered log entries into their
#    real home at $EMACS_DIR/emacs_setup_log.txt and log there from now on.
cat "$LOG_BUFFER" >"$LOG_FILE"
rm -f "$LOG_BUFFER"
CURRENT_LOG="$LOG_FILE"
log "[✓] Log file initialized at $LOG_FILE"

# 6. Sanity-check that config.org actually made it into the clone before we
#    try to tangle it.
if [ ! -f "$CONFIG_ORG" ]; then
  log "[✗] Error: config.org not found at $CONFIG_ORG after cloning."
  exit 1
fi

# Helper: returns success (0) if an Emacs daemon is currently reachable
is_daemon_running() {
  emacsclient -e '(+ 1 1)' >/dev/null 2>&1
}

# 7. Tangle config.org into the actual elisp configuration files.
#    We pass the fully-resolved path (not "~/...") so there's no ambiguity
#    about tilde expansion inside the Elisp string literal.
log "[*] Tangling $CONFIG_ORG ..."
log "---------------------------------------------------------------- [tangle output begin]"
run_and_log emacs --batch \
  --eval "(require 'org)" \
  --eval "(org-babel-tangle-file \"${CONFIG_ORG}\")"
log "---------------------------------------------------------------- [tangle output end]"
log "[✓] Tangling complete. Full output logged to: $LOG_FILE"

# 8. Make sure no Emacs daemon is left running before we start a fresh one.
#    emacsclient's kill request occasionally fails to terminate the daemon on
#    the first try, so we retry a bounded number of times rather than assuming
#    a single call is enough.
if is_daemon_running; then
  log "[*] An existing Emacs daemon was detected. Attempting to stop it..."
  attempt=1
  while [ "$attempt" -le "$MAX_KILL_ATTEMPTS" ] && is_daemon_running; do
    log "[*] Kill attempt ${attempt}/${MAX_KILL_ATTEMPTS}..."
    emacsclient -e "(kill-emacs)" >/dev/null 2>&1 || true
    sleep 1
    attempt=$((attempt + 1))
  done

  if is_daemon_running; then
    log "[✗] Error: Failed to kill the running Emacs daemon after ${MAX_KILL_ATTEMPTS} attempts."
    exit 1
  fi
  log "[✓] Existing Emacs daemon stopped."
else
  log "[*] No running Emacs daemon detected. Proceeding cleanly..."
fi

# 9. Start the Emacs daemon. This loads the freshly tangled configuration and
#    performs any first-run package installation/setup defined in it.
log "[*] Starting Emacs daemon..."
emacs --daemon

# 10. Confirm the new daemon is actually up and responsive.
sleep 1
if is_daemon_running; then
  log "[✓] Emacs daemon is running and responsive."
else
  log "[✗] Warning: Emacs daemon was started but is not responding to emacsclient."
fi

log "----------------------------------------------------------------------"
log "[✓] Vanilla Emacs setup script has finished execution."
log "Run finished: $(date '+%Y-%m-%d %H:%M:%S')"
