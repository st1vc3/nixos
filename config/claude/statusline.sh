#!/usr/bin/env bash
# Claude Code status line: shows the active model and how full the context
# window is, e.g. "Opus · 27k/200k (13%)".
#
# Claude Code pipes a JSON status payload on stdin on every render (see
# https://docs.claude.com/en/docs/claude-code/statusline). The payload does not
# carry a context-usage number directly, so we read it from the session
# transcript: the most recent message with a `usage` block reflects the current
# window occupancy (prompt tokens plus everything served from / written to the
# prompt cache).
#
# Note: no `set -e`. We read the transcript back-to-front with `tac` and stop at
# the first usage block; breaking out of that pipeline hands `tac` a SIGPIPE,
# and under `set -e` the non-zero status would abort the script before it prints.
set -uo pipefail

input=$(cat)

model=$(printf '%s' "$input" | jq -r '.model.display_name // "Claude"')
transcript=$(printf '%s' "$input" | jq -r '.transcript_path // empty')

# Opus/Sonnet expose a 200k-token context window; used as the denominator.
limit=200000

ctx=""
if [[ -n "$transcript" && -f "$transcript" ]]; then
  used=$(tac "$transcript" | while IFS= read -r line; do
    tokens=$(printf '%s' "$line" \
      | jq -r 'select(.message.usage != null)
               | .message.usage
               | (.input_tokens // 0)
                 + (.cache_read_input_tokens // 0)
                 + (.cache_creation_input_tokens // 0)' 2>/dev/null)
    if [[ -n "$tokens" ]]; then
      printf '%s' "$tokens"
      break
    fi
  done)
  if [[ -n "${used:-}" && "$used" -gt 0 ]]; then
    pct=$(( used * 100 / limit ))
    ctx=$(printf ' · %dk/%dk (%d%%)' $(( used / 1000 )) $(( limit / 1000 )) "$pct")
  fi
fi

printf '%s%s' "$model" "$ctx"
