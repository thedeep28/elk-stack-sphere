#!/usr/bin/env bash
set -euo pipefail

state=/run/elk-lab/attack-active.json
log=/var/log/elk-lab/attacks.jsonl

if [[ -r "$state" ]]; then
  jq . "$state"
else
  echo '{"active":false,"detail":"no campaign has run since boot"}'
fi

echo 'Recent campaign actions:'
if [[ -r "$log" ]]; then
  tail -n 20 "$log" | jq -c . || true
else
  echo 'Ground truth is protected; run sudo attack-status after freezing detections.'
fi
