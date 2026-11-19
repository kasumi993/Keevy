#!/usr/bin/env bash
# Posts a commit comment summarising CI steps, so results are readable from the
# GitHub REST API (commit comments) without downloading logs.
# Usage: report.sh <job-name> "<step>:<exit-code>:<logfile>" ...
set -u
job="$1"; shift
out="ci-report.md"
{
  echo "### CI \`${job}\` — ${GITHUB_SHA:0:7}"
  echo
  for spec in "$@"; do
    step="${spec%%:*}"; rest="${spec#*:}"
    code="${rest%%:*}"; file="${rest#*:}"
    if [ -z "$code" ]; then status="⏭️ skipped"; elif [ "$code" = "0" ]; then status="✅"; else status="❌ (exit $code)"; fi
    echo "**${step}** ${status}"
    if [ -n "$code" ] && [ -f "$file" ]; then
      if [ "$code" = "0" ]; then n=15; else n=220; fi
      if [ "$step" = "analyze" ]; then
        # Analyzer output: keep every issue line (they are the useful part).
        body=$(grep -E '^\s*(error|warning|info) •' "$file" | head -n 300)
        [ -z "$body" ] && body=$(tail -n "$n" "$file")
      else
        body=$(tail -n "$n" "$file")
      fi
      echo '```'
      echo "$body" | cut -c1-400
      echo '```'
    fi
    echo
  done
} > "$out"
# GitHub comment bodies are capped at 65536 chars.
head -c 60000 "$out" > "${out}.trim"
gh api "repos/${GITHUB_REPOSITORY}/commits/${GITHUB_SHA}/comments" -F "body=@${out}.trim" > /dev/null || cat "$out"
