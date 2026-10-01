#!/usr/bin/env bash
set -euo pipefail

config=/etc/default/elk-lab-benign
[[ -r "$config" ]] && source "$config"

: "${CLIENT_COUNT:=8}"
if (( CLIENT_COUNT < 1 || CLIENT_COUNT > 20 )); then
  echo "CLIENT_COUNT must be between 1 and 20" >&2
  exit 2
fi

pids=()
stop_workers() {
  trap - TERM INT EXIT
  ((${#pids[@]} == 0)) || kill "${pids[@]}" 2>/dev/null || true
  ((${#pids[@]} == 0)) || wait "${pids[@]}" 2>/dev/null || true
}
trap stop_workers TERM INT EXIT

for client_id in $(seq 1 "$CLIENT_COUNT"); do
  /opt/elk-lab/benign-worker.sh "$client_id" &
  pids+=("$!")
done

wait "${pids[@]}"
