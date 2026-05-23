#!/usr/bin/env bash
# codex-dispatch.sh — canonical codex exec wrapper for the code-writer contract.
#
# Wraps `codex exec` with this fork's conventions automatically:
# --skip-git-repo-check, brief-declared sandbox tier, stderr to a random /tmp
# log, heredoc prompt via stdin. Defaults to the code-writer persona; if stdin
# already looks like a brief (starts with `## Task`), it's forwarded verbatim,
# otherwise it's wrapped in the code-writer template with stdin as the Task body.
#
# Usage:
#   ./scripts/codex-dispatch.sh [OPTIONS] [<task>]
#   ./scripts/codex-dispatch.sh [OPTIONS] <<'EOF'
#   ## Task
#   ...full brief...
#   EOF
#
# Options:
#   --tier <tier>        network | workspace | system   (default: network)
#                        Maps to:
#                          network   -> --dangerously-bypass-approvals-and-sandbox
#                          workspace -> --full-auto
#                          system    -> --dangerously-bypass-approvals-and-sandbox
#                        Default is `network` because it's the most common case
#                        (code writing + dep installs + research). Tighten to
#                        `workspace` only when you explicitly want to block
#                        network access.
#   --persona <name>     Persona file to use (default: code-writer).
#                        Looks up personas/<name>.md in repo.
#   --effort <level>     low | medium | high | default   (default: default)
#                        Sets model_reasoning_effort.
#   --cd <dir>           Set Codex working directory (-C).
#   --profile <name>     Use a codex config profile (-p).
#   --resume             Resume the last session instead of starting fresh.
#                        --tier/--effort/--profile are ignored on resume
#                        (session inherits from the original dispatch).
#   --raw                Skip persona/template wrapping entirely; forward stdin
#                        to codex exec verbatim. Useful for ad-hoc dispatches
#                        that aren't briefs.
#   --show-stderr        Print the /tmp log on exit (for debugging).
#   --debug              Print the assembled command and exit 0 without running.
#   -h, --help           Show this help.
#
# Exit codes:
#   0    success
#   1    usage error
#   2    codex binary not found
#   3    persona file not found
#   N    codex's exit code on failure
#
# Environment:
#   CODEX_DISPATCH_TMPDIR  override /tmp for log files (default: /tmp)

set -euo pipefail

usage() {
  sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'
  exit "${1:-0}"
}

# --- defaults ---
TIER="network"
PERSONA="code-writer"
EFFORT="default"
CD_DIR=""
PROFILE=""
RESUME=0
RAW=0
SHOW_STDERR=0
DEBUG=0
TASK_ARG=""

# --- arg parsing ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --tier)        TIER="$2"; shift 2 ;;
    --persona)     PERSONA="$2"; shift 2 ;;
    --effort)      EFFORT="$2"; shift 2 ;;
    --cd)          CD_DIR="$2"; shift 2 ;;
    --profile)     PROFILE="$2"; shift 2 ;;
    --resume)      RESUME=1; shift ;;
    --raw)         RAW=1; shift ;;
    --show-stderr) SHOW_STDERR=1; shift ;;
    --debug)       DEBUG=1; shift ;;
    -h|--help)     usage 0 ;;
    --)            shift; TASK_ARG="${*:-}"; break ;;
    -*)            echo "unknown option: $1" >&2; usage 1 >&2 ;;
    *)             TASK_ARG="$*"; break ;;
  esac
done

# --- sanity checks ---
if ! command -v codex >/dev/null 2>&1; then
  echo "error: codex CLI not found on PATH" >&2
  echo "install: npm install -g @openai/codex && codex login" >&2
  exit 2
fi

# --- read stdin if available ---
STDIN_BODY=""
if [[ ! -t 0 ]]; then
  STDIN_BODY="$(cat)"
fi

# --- map tier to sandbox flags + web_search toggle ---
# network and system enable codex's native web_search tool (Responses API),
# since research is part of why those tiers exist. workspace explicitly does not.
case "$TIER" in
  network)   SANDBOX_FLAGS=(--dangerously-bypass-approvals-and-sandbox)
             WEB_SEARCH=1 ;;
  workspace) SANDBOX_FLAGS=(--full-auto)
             WEB_SEARCH=0 ;;
  system)    SANDBOX_FLAGS=(--dangerously-bypass-approvals-and-sandbox)
             WEB_SEARCH=1 ;;
  *)         echo "error: unknown tier: $TIER (want: network|workspace|system)" >&2; exit 1 ;;
esac

# --- assemble the prompt ---
# Priority: explicit stdin > task arg. If neither, error.
if [[ -n "$STDIN_BODY" ]]; then
  RAW_INPUT="$STDIN_BODY"
elif [[ -n "$TASK_ARG" ]]; then
  RAW_INPUT="$TASK_ARG"
else
  echo "error: no input provided (pass via stdin or positional arg)" >&2
  usage 1 >&2
fi

if [[ $RAW -eq 1 ]] || [[ $RESUME -eq 1 ]]; then
  # raw + resume: forward verbatim. (resume inherits persona from the original session.)
  PROMPT="$RAW_INPUT"
else
  # Extract ONLY the Codex-facing contract slice from the persona file.
  # The rest of the persona file is Claude-facing and would just pollute
  # Codex's context.
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  PERSONA_FILE="$SCRIPT_DIR/../personas/${PERSONA}.md"
  if [[ ! -f "$PERSONA_FILE" ]]; then
    echo "error: persona file not found: $PERSONA_FILE" >&2
    exit 3
  fi
  CONTRACT="$(awk '/<!-- CODEX_CONTRACT_BEGIN -->/{f=1; next} /<!-- CODEX_CONTRACT_END -->/{f=0} f' "$PERSONA_FILE")"
  if [[ -z "$CONTRACT" ]]; then
    echo "error: $PERSONA_FILE has no CODEX_CONTRACT_BEGIN/END markers" >&2
    exit 3
  fi

  if printf '%s' "$RAW_INPUT" | grep -q '^## Task'; then
    PROMPT="=== CONTRACT ===
$CONTRACT
=== TASK ===
$RAW_INPUT"
  else
    PROMPT="=== CONTRACT ===
$CONTRACT
=== TASK ===
The dispatcher passed only a bare task statement (sandbox tier: $TIER). Treat the line below as the Task section. Infer minimal Scope and Self-check from the task; if too ambiguous, return blocked.

## Task
$RAW_INPUT"
  fi
fi

# --- build command pieces ---
TMPDIR_="${CODEX_DISPATCH_TMPDIR:-/tmp}"
mkdir -p "$TMPDIR_"
if command -v openssl >/dev/null 2>&1; then
  RAND_SUFFIX="$(openssl rand -hex 4)"
else
  RAND_SUFFIX="$(date +%s%N | sha256sum | head -c 8)"
fi
LOGFILE="$TMPDIR_/codex-${RAND_SUFFIX}.log"

CMD=(codex exec --skip-git-repo-check)
if [[ $RESUME -eq 1 ]]; then
  CMD+=(resume --last)
else
  CMD+=("${SANDBOX_FLAGS[@]}")
  [[ "${WEB_SEARCH:-0}" -eq 1 ]] && CMD+=(--config "tools.web_search=true")
fi
[[ -n "$CD_DIR"  ]] && CMD+=(-C "$CD_DIR")
[[ -n "$PROFILE" ]] && [[ $RESUME -eq 0 ]] && CMD+=(-p "$PROFILE")
if [[ "$EFFORT" != "default" ]] && [[ $RESUME -eq 0 ]]; then
  CMD+=(--config "model_reasoning_effort=\"$EFFORT\"")
fi

# --- debug mode: print and exit ---
if [[ $DEBUG -eq 1 ]]; then
  echo "Would run:"
  printf '  %q ' "${CMD[@]}"
  echo
  echo "Stderr log: $LOGFILE"
  echo "Prompt (first 400 chars):"
  echo "${PROMPT:0:400}"
  exit 0
fi

# --- dispatch ---
# fresh and resume both feed prompt via stdin
printf '%s\n' "$PROMPT" | "${CMD[@]}" 2>>"$LOGFILE"
EXIT_CODE=$?

if [[ $SHOW_STDERR -eq 1 ]] || [[ $EXIT_CODE -ne 0 ]]; then
  echo "--- stderr log: $LOGFILE ---" >&2
  cat "$LOGFILE" >&2
fi

exit $EXIT_CODE
