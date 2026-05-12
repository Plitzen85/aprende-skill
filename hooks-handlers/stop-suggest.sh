#!/usr/bin/env bash
# aprende — Stop hook reminder
#
# At session end, check whether /aprende has signals to process. If so, emit
# additionalContext via the hook JSON output protocol so the user/agent sees
# a one-line nudge in the next interaction. Does not write anything.
#
# Safe: read-only on the signals file. Exit 0 always.

set -u

# --- derive project slug --------------------------------------------------
project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"
slug=$(echo "$project_dir" | sed 's|/|-|g')
slug="${slug%-}"

signals_file="${HOME}/.claude/projects/${slug}/.aprende-signals.md"

# --- check signals file ---------------------------------------------------
if [[ ! -s "$signals_file" ]]; then
  # No signals captured this session. Nothing to suggest.
  exit 0
fi

count=$(wc -l < "$signals_file" 2>/dev/null | tr -d ' ')
[[ -z "$count" || "$count" -eq 0 ]] && exit 0

# --- emit additionalContext via hook JSON output --------------------------
# Claude Code reads stdout as JSON for Stop hooks. The `additionalContext`
# field is shown to the agent on next turn.
msg_en="aprende: ${count} learning signal(s) captured this session were not reviewed. Run /aprende before closing to crystallize them."
msg_es="aprende: se capturaron ${count} señal(es) de aprendizaje sin revisar. Corre /aprende antes de cerrar para guardarlas."

# JSON-escape is trivial here (no special chars in our strings).
cat <<EOF
{
  "additionalContext": "$msg_en\n$msg_es"
}
EOF

exit 0
