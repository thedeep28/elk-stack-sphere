#!/usr/bin/env bash
set -uo pipefail

log=/var/log/elk-lab/attacks.jsonl
state_dir=/run/elk-lab
state_file=${state_dir}/attack-active.json
iface=$(ip -o -4 addr show | awk '$4 ~ /^172\.17\.1\.2\// {print $2; exit}')
if [[ -z "${iface:-}" ]]; then
  echo 'Could not find the SPHERE interface for 172.17.1.2' >&2
  exit 1
fi
campaign_id="campaign-$(date +%s)-${RANDOM}"
campaign_start=$(date --iso-8601=ns)
mkdir -p "$state_dir"

guard_target() {
  case "$1" in
    10.10.10.10|192.168.50.20) return 0 ;;
    *) echo "Refusing non-lab target: $1" >&2; return 1 ;;
  esac
}

now_ms() { date +%s%3N; }
new_id() { printf '%s-%s-%s\n' "$1" "$(date +%s%N)" "$RANDOM"; }

append_json() {
  local json=$1
  {
    flock -x 9
    printf '%s\n' "$json" >&9
  } 9>>"$log"
}

log_action() {
  local class=$1 behavior=$2 action=$3 src=$4 dst=$5 port=$6 outcome=$7
  local started=$8 ended=$9 duration_ms=${10} detail=${11}
  append_json "$(jq -nc \
    --arg ts "$started" --arg end "$ended" --arg campaign "$campaign_id" --arg id "$(new_id "$behavior")" \
    --arg class "$class" --arg behavior "$behavior" --arg action "$action" --arg src "$src" --arg dst "$dst" \
    --argjson port "$port" --arg outcome "$outcome" --argjson duration "$duration_ms" --arg detail "$detail" \
    '{"@timestamp":$ts,"event.end":$end,"campaign.id":$campaign,"event.id":$id,"traffic.class":$class,"attack.behavior":$behavior,"event.action":$action,"source.ip":$src,"destination.ip":$dst,"destination.port":$port,"event.outcome":$outcome,"event.duration_ms":$duration,"detail":$detail,"bounded":true}')"
}

log_campaign_marker() {
  local action=$1 timestamp=$2 detail=$3
  append_json "$(jq -nc --arg ts "$timestamp" --arg campaign "$campaign_id" --arg action "$action" --arg detail "$detail" \
    '{"@timestamp":$ts,"campaign.id":$campaign,"traffic.class":"attack","event.kind":"campaign","event.action":$action,"detail":$detail,"bounded":true}')"
}

write_state() {
  local active=$1 ended=${2:-}
  jq -nc --argjson active "$active" --arg id "$campaign_id" --arg start "$campaign_start" --arg end "$ended" \
    --arg scan "$scan_src" --arg ssh "$ssh_src" --arg web "$web_src" \
    '{"campaign.id":$id,active:$active,started:$start,ended:$end,workers:[{"name":"port_scan","source.ip":$scan},{"name":"ssh_password_guessing","source.ip":$ssh},{"name":"web_enumeration","source.ip":$web}]}' \
    >"${state_file}.tmp"
  mv "${state_file}.tmp" "$state_file"
}

scan_worker() {
  local src=$1 target=10.10.10.10 port output state started ended start_ms end_ms
  guard_target "$target" || return 2
  for port in 21 22 53 80 443; do
    started=$(date --iso-8601=ns); start_ms=$(now_ms)
    output=$(timeout 15 nmap -n -Pn -sS -T3 --max-rate 20 -p "$port" \
      -S "$src" -e "$iface" -oG - "$target" 2>/dev/null || true)
    ended=$(date --iso-8601=ns); end_ms=$(now_ms)
    if grep -q "${port}/open/" <<<"$output"; then state=open
    elif grep -q "${port}/closed/" <<<"$output"; then state=closed
    elif grep -q "${port}/filtered/" <<<"$output"; then state=filtered
    else state=unknown; fi
    log_action attack port_scan probe "$src" "$target" "$port" "$state" \
      "$started" "$ended" "$((end_ms - start_ms))" 'tcp_syn_scan max_rate=20'
  done
}

ssh_worker() {
  local src=$1 target=192.168.50.20 password candidate rc started ended start_ms end_ms outcome
  local -a passwords=(password admin123 letmein welcome)
  guard_target "$target" || return 2
  for candidate in "${!passwords[@]}"; do
    password=${passwords[$candidate]}
    started=$(date --iso-8601=ns); start_ms=$(now_ms)
    timeout 8 sshpass -p "$password" ssh -b "$src" \
      -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=3 \
      labadmin@"$target" true >/dev/null 2>&1
    rc=$?
    ended=$(date --iso-8601=ns); end_ms=$(now_ms)
    (( rc == 0 )) && outcome=accepted || outcome=rejected
    log_action attack ssh_password_guessing authentication_attempt "$src" "$target" 22 "$outcome" \
      "$started" "$ended" "$((end_ms - start_ms))" "username=labadmin credential_id=candidate-$((candidate + 1))"
    sleep 2
  done
}

web_worker() {
  local src=$1 target=10.10.10.10 path output code bytes seconds started ended start_ms end_ms outcome
  local -a paths=(admin login private backup .git/config robots.txt)
  guard_target "$target" || return 2
  for path in "${paths[@]}"; do
    started=$(date --iso-8601=ns); start_ms=$(now_ms)
    output=$(curl --interface "$src" -sS -o /dev/null --max-time 8 \
      -A 'BlueMon-baseline-enumerator/2.0' -w '%{http_code} %{size_download} %{time_total}' \
      "http://${target}/${path}" 2>/dev/null || true)
    ended=$(date --iso-8601=ns); end_ms=$(now_ms)
    read -r code bytes seconds <<<"${output:-000 0 0}"
    [[ "$code" =~ ^[1-5][0-9][0-9]$ ]] && outcome=completed || outcome=failed
    log_action attack web_enumeration request "$src" "$target" 80 "$outcome" \
      "$started" "$ended" "$((end_ms - start_ms))" "method=GET path=/${path} status=${code:-000} bytes=${bytes:-0}"
    sleep 2
  done
}

cover_worker() {
  local src target=10.10.10.10 output code bytes seconds started ended start_ms end_ms outcome
  guard_target "$target" || return 2
  for src in "$scan_src" "$ssh_src" "$web_src"; do
    started=$(date --iso-8601=ns); start_ms=$(now_ms)
    output=$(curl --interface "$src" -sS -o /dev/null --max-time 8 \
      -A 'Mozilla/5.0 BlueMon mixed-source' -w '%{http_code} %{size_download} %{time_total}' \
      "http://${target}/?campaign=${campaign_id}" 2>/dev/null || true)
    ended=$(date --iso-8601=ns); end_ms=$(now_ms)
    read -r code bytes seconds <<<"${output:-000 0 0}"
    [[ "$code" == 200 ]] && outcome=success || outcome=failed
    log_action benign-cover cover_request request "$src" "$target" 80 "$outcome" \
      "$started" "$ended" "$((end_ms - start_ms))" "method=GET path=/ status=${code:-000} bytes=${bytes:-0}"
    sleep 1
  done
}

mapfile -t selected_sources < <(seq 10 29 | shuf | head -n 3)
scan_src="172.17.20.${selected_sources[0]}"
ssh_src="172.17.20.${selected_sources[1]}"
web_src="172.17.20.${selected_sources[2]}"

finalized=false
finalize() {
  local ended
  [[ "$finalized" == true ]] && return
  finalized=true
  ended=$(date --iso-8601=ns)
  log_campaign_marker campaign_end "$ended" 'parallel workers finished or were interrupted'
  write_state false "$ended"
}
trap finalize EXIT
trap 'finalize; exit 143' TERM
trap 'finalize; exit 130' INT

write_state true
log_campaign_marker campaign_start "$campaign_start" 'parallel scan, SSH, Web, and cover workers started'

scan_worker "$scan_src" & scan_pid=$!
ssh_worker "$ssh_src" & ssh_pid=$!
web_worker "$web_src" & web_pid=$!
cover_worker & cover_pid=$!

wait "$scan_pid" "$ssh_pid" "$web_pid" "$cover_pid" || true
