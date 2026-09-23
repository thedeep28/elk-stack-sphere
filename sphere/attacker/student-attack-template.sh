#!/usr/bin/env bash
set -euo pipefail

# Copy this file; do not edit the baseline. Keep explicit scope and rate caps.
scenario_id="CHANGE-ME"
target="10.10.10.10"
max_actions=20

case "$target" in
  10.10.10.10|192.168.50.20) ;;
  *) echo "Refusing non-lab target: $target" >&2; exit 2 ;;
esac

if (( max_actions > 50 )); then
  echo 'Refusing more than 50 actions in a student scenario' >&2
  exit 2
fi

echo "Implement a reviewed, bounded scenario here: ${scenario_id}" >&2
exit 1

