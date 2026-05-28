#!/usr/bin/env bash
# Claude Code status line
# Shows: cwd | model [effort] | context usage (colored green/yellow/red)

input=$(cat)

cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // empty | gsub("\\\\"; "/") | split("/") | last')
model=$(echo "$input" | jq -r '.model.display_name // empty')
used=$(echo "$input" | jq -r '.context_window.current_usage.input_tokens // empty')
total=$(echo "$input" | jq -r '.context_window.context_window_size // empty')
pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# Color codes
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
RESET='\033[0m'

# Build context segment with color
if [ -n "$pct" ] && [ -n "$used" ] && [ -n "$total" ]; then
  pct_int=$(printf '%.0f' "$pct")
  if [ "$pct_int" -lt 50 ]; then
    color="$GREEN"
  elif [ "$pct_int" -le 80 ]; then
    color="$YELLOW"
  else
    color="$RED"
  fi
  ctx_str="${used}/${total} (${pct_int}%)"
  ctx_colored=$(printf "${color}%s${RESET}" "$ctx_str")
else
  ctx_colored="no data"
fi

printf "%s | %s | %s" "$cwd" "$model" "$ctx_colored"
