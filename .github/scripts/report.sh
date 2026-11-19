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
      if [ "$code" = "0" ]; then n=12; else n=200; fi
      if [ "$step" = "analyze" ]; then
        # Errors and warnings first; infos are summarised (deprecations are noisy).
        errs=$(grep -E '^\s*(error|warning) •' "$file" | head -n 150)
        infos=$(grep -E '^\s*info •' "$file" | grep -v "package:flutter/material.dart' is deprecated" | head -n 60)
        ninfo=$(grep -cE '^\s*info •' "$file")
        body="${errs}"$'\n'"--- infos (${ninfo} total, material.dart deprecation hidden) ---"$'\n'"${infos}"
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
head -c 60000 "$out" > "${out}.trim"
gh api "repos/${GITHUB_REPOSITORY}/commits/${GITHUB_SHA}/comments" -F "body=@${out}.trim" > /dev/null || cat "$out"
