#!/usr/bin/env bash
# Fails if line coverage in coverage/lcov.info is below the threshold.
# Generated localisation files are excluded.
# Usage: tool/check_coverage.sh [min_percent]
set -euo pipefail

min="${1:-80}"
file="coverage/lcov.info"

awk -v min="$min" '
  /^SF:/ { skip = ($0 ~ /lib[\/\\]l10n[\/\\]app_localizations/) }
  /^LF:/ && !skip { split($0, a, ":"); found += a[2] }
  /^LH:/ && !skip { split($0, a, ":"); hit += a[2] }
  END {
    if (found == 0) { print "No coverage data"; exit 1 }
    pct = hit * 100 / found
    printf "Line coverage: %.1f%% (%d/%d lines), minimum %d%%\n", pct, hit, found, min
    if (pct < min) exit 1
  }
' "$file"
