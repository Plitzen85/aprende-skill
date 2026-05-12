#!/usr/bin/env bash
# aprende — PostToolUse signal capture
#
# Reads the hook JSON payload from stdin and appends a signal record to
# ~/.claude/projects/<slug>/.aprende-signals.md when something interesting
# happened (non-zero exit code, error in stderr, repeated edit to the same
# file, repeated bash retry).
#
# This script NEVER writes a learning. It only accumulates signal records.
# The /aprende slash command reads this file in Pass A.
#
# Safe: every operation is append-only on a per-session scratch file. No
# user files are modified. No tool calls are blocked. Exit code is always 0.

set -u  # treat unset vars as errors; do not set -e (we never want to fail the hook)

# --- read payload ---------------------------------------------------------
payload=$(cat 2>/dev/null || true)
if [[ -z "$payload" ]]; then
  exit 0
fi

# --- derive project slug --------------------------------------------------
# CLAUDE_PROJECT_DIR is set by Claude Code to the project root.
# Fallback: pwd. Convert /a/b/c -> -a-b-c (matches the existing convention).
project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
slug=$(echo "$project_dir" | sed 's|/|-|g')
# strip a single trailing dash if pwd had a trailing slash
slug="${slug%-}"

signals_dir="${HOME}/.claude/projects/${slug}"
signals_file="${signals_dir}/.aprende-signals.md"

mkdir -p "$signals_dir" 2>/dev/null || exit 0

# --- inspect payload ------------------------------------------------------
# We avoid hard jq dependency; use bash + grep. The hook JSON has fields:
# tool_name, tool_input, tool_response (with success/error fields).
tool_name=$(printf '%s' "$payload" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')

# Detect failure signals (any of these patterns in the payload):
is_error=0
if printf '%s' "$payload" | grep -qE '"is_error"[[:space:]]*:[[:space:]]*true'; then
  is_error=1
fi
if printf '%s' "$payload" | grep -qE '"exit_code"[[:space:]]*:[[:space:]]*[1-9]'; then
  is_error=1
fi
if printf '%s' "$payload" | grep -qiE '(error|exception|failed|fatal|traceback)' >/dev/null; then
  # Heuristic: error keyword in tool response. Only count if not the user input.
  if printf '%s' "$payload" | grep -qE '"tool_response"' && \
     printf '%s' "$payload" | grep -qE '"(stderr|output|error)"'; then
    is_error=1
  fi
fi

# --- write signal record --------------------------------------------------
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
if [[ $is_error -eq 1 ]]; then
  printf -- '- %s  error-from-%s\n' "$timestamp" "${tool_name:-unknown}" >> "$signals_file"
fi

# Track repeated edits: if the same file appears in an Edit/Write tool_input
# 3+ times today, that's a repeated-attempt signal. We use a per-day counter.
if [[ "$tool_name" == "Edit" || "$tool_name" == "Write" ]]; then
  file_path=$(printf '%s' "$payload" | grep -o '"file_path"[[:space:]]*:[[:space:]]*"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
  if [[ -n "$file_path" ]]; then
    counter_file="${signals_dir}/.aprende-edit-counts.tsv"
    today=$(date -u +"%Y-%m-%d")
    # increment the count for this file today
    if [[ -f "$counter_file" ]]; then
      prev=$(grep -F "${today}	${file_path}" "$counter_file" | head -1 | awk -F'\t' '{print $3}')
      prev="${prev:-0}"
    else
      prev=0
    fi
    new=$((prev + 1))
    # rewrite line (or append)
    if grep -qF "${today}	${file_path}" "$counter_file" 2>/dev/null; then
      # macOS-compatible in-place sed
      tmpfile=$(mktemp)
      awk -F'\t' -v t="$today" -v f="$file_path" -v n="$new" '
        $1==t && $2==f { printf "%s\t%s\t%s\n", t, f, n; next }
        { print }
      ' "$counter_file" > "$tmpfile" && mv "$tmpfile" "$counter_file"
    else
      printf '%s\t%s\t%s\n' "$today" "$file_path" "$new" >> "$counter_file"
    fi
    if [[ $new -eq 3 ]]; then
      printf -- '- %s  repeated-edit %s (3x today)\n' "$timestamp" "$file_path" >> "$signals_file"
    fi
  fi
fi

exit 0
