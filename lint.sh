#!/bin/bash
# lint.sh — shellcheck gate for the review-campaign lockdown (R10).
# Must exit 0 with "shellcheck: CLEAN" — any new finding fails the gate.
# The single tolerated directive is SC2068 on the whiptail --menu line (documented in pisafe).
cd -- "$(dirname -- "${BASH_SOURCE[0]}")" || exit 1

OUT=$(shellcheck -s bash -f gcc pisafe 2>/dev/null)
if [[ -z "$OUT" ]]; then
    echo "shellcheck: CLEAN (0 findings)"
    exit 0
fi

COUNT=$(printf '%s\n' "$OUT" | grep -c .)
printf '%s\n' "$OUT"
echo "shellcheck: $COUNT finding(s)"
exit 1
