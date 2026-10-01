#!/usr/bin/env bash
set -uo pipefail

mode=${1:?usage: benign-worker.sh CLIENT_ID}
if [[ "$mode" == --ftp-child ]]; then
  client_id=${2:?}; src=${3:?}; child_ftp_size=${4:?}; child_ftp_direction=${5:?}
else
  client_id=$mode
  src="172.16.10.$((9 + client_id))"
fi
config=/etc/default/elk-lab-benign
[[ -r "$config" ]] && source "$config"

: "${WEIGHT_TOTAL:=10000}" "${WEB_WEIGHT:=9216}" "${SSH_WEIGHT:=754}" "${FTP_WEIGHT:=30}"
: "${THINK_MIN_SECONDS:=5}" "${THINK_MAX_SECONDS:=25}"
: "${WEB_REQUEST_MIN:=2}" "${WEB_REQUEST_MAX:=8}" "${WEB_THINK_MAX_SECONDS:=3}"
: "${FTP_MAX_SIMULTANEOUS_LARGE:=1}"

if (( WEB_WEIGHT + SSH_WEIGHT + FTP_WEIGHT != WEIGHT_TOTAL )); then
  echo "protocol weights must sum to WEIGHT_TOTAL" >&2
  exit 2
fi
if (( FTP_MAX_SIMULTANEOUS_LARGE != 1 )); then
  echo "FTP_MAX_SIMULTANEOUS_LARGE currently supports only 1" >&2
  exit 2
fi

log=/var/log/elk-lab/benign.jsonl
large_lock=/run/lock/elk-lab-large-ftp.lock

random_between() {
  local min=$1 max=$2 span random_value
  (( max >= min )) || return 2
  span=$((max - min + 1))
  random_value=$((RANDOM * 1073741824 + RANDOM * 32768 + RANDOM))
  printf '%d\n' "$((min + random_value % span))"
}

now_ms() { date +%s%3N; }
new_id() { printf '%s-%s-%s-%s\n' "$1" "$(date +%s%N)" "$client_id" "$RANDOM"; }

append_json() {
  local json=$1
  {
    flock -x 9
    printf '%s\n' "$json" >&9
  } 9>>"$log"
}

record_event() {
  local event_id=$1 parent_id=$2 protocol=$3 destination=$4 success=$5
  local started=$6 ended=$7 duration_ms=$8 bytes_sent=$9 bytes_received=${10} detail=${11}
  append_json "$(jq -nc \
    --arg ts "$started" --arg end "$ended" --arg id "$event_id" --arg parent "$parent_id" \
    --arg client "$client_id" --arg proto "$protocol" --arg src "$src" --arg dst "$destination" \
    --argjson ok "$success" --argjson duration "$duration_ms" --argjson sent "$bytes_sent" \
    --argjson received "$bytes_received" --arg detail "$detail" \
    '{"@timestamp":$ts,"event.end":$end,"event.id":$id,"event.parent_id":$parent,"client.id":$client,"traffic.class":"benign","network.protocol":$proto,"source.ip":$src,"destination.ip":$dst,"event.success":$ok,"event.duration_ms":$duration,"source.bytes":$sent,"destination.bytes":$received,"detail":$detail}')"
}

web_session() {
  local session_id count i path ua output code bytes seconds start_iso end_iso start_ms end_ms ok
  local -a paths=(/ /health /robots.txt / /login / /private/missing)
  local -a agents=('Mozilla/5.0 BlueMon-client' 'curl/BlueMon' 'BlueMon-browser/2.0')
  session_id=$(new_id web-session)

  start_iso=$(date --iso-8601=ns)
  start_ms=$(now_ms)
  output=$(dig -b "$src" +short +time=2 +tries=1 @10.10.10.10 portal.corp.test 2>/dev/null || true)
  end_ms=$(now_ms); end_iso=$(date --iso-8601=ns)
  [[ "$output" == *10.10.10.10* ]] && ok=true || ok=false
  record_event "$(new_id dns)" "$session_id" dns 10.10.10.10 "$ok" "$start_iso" "$end_iso" \
    "$((end_ms - start_ms))" 0 0 'portal.corp.test'

  count=$(random_between "$WEB_REQUEST_MIN" "$WEB_REQUEST_MAX")
  for i in $(seq 1 "$count"); do
    path=${paths[RANDOM % ${#paths[@]}]}
    ua=${agents[RANDOM % ${#agents[@]}]}
    start_iso=$(date --iso-8601=ns); start_ms=$(now_ms)
    output=$(curl --interface "$src" -sS -o /dev/null --max-time 15 \
      -A "$ua" -w '%{http_code} %{size_download} %{time_total}' \
      "http://10.10.10.10${path}?session=${session_id}&request=${i}" 2>/dev/null || true)
    end_ms=$(now_ms); end_iso=$(date --iso-8601=ns)
    read -r code bytes seconds <<<"${output:-000 0 0}"
    [[ "$code" =~ ^(200|401|403|404)$ ]] && ok=true || ok=false
    record_event "$(new_id http)" "$session_id" http 10.10.10.10 "$ok" "$start_iso" "$end_iso" \
      "$((end_ms - start_ms))" 0 "${bytes:-0}" "method=GET path=${path} status=${code:-000} ua=${ua}"
    sleep "$(random_between 0 "$WEB_THINK_MAX_SECONDS")"
  done
}

sample_ssh_duration() {
  local roll
  roll=$(random_between 1 1000)
  if (( roll <= SSH_CDF_SHORT )); then random_between "$SSH_SHORT_MIN_SECONDS" "$SSH_SHORT_MAX_SECONDS"
  elif (( roll <= SSH_CDF_MEDIUM )); then random_between "$SSH_MEDIUM_MIN_SECONDS" "$SSH_MEDIUM_MAX_SECONDS"
  elif (( roll <= SSH_CDF_LONG )); then random_between "$SSH_LONG_MIN_SECONDS" "$SSH_LONG_MAX_SECONDS"
  else random_between "$SSH_RARE_MIN_SECONDS" "$SSH_RARE_MAX_SECONDS"
  fi
}

ssh_session() {
  local event_id duration start_iso end_iso start_ms end_ms ok tag
  event_id=$(new_id ssh); tag=${event_id}; duration=$(sample_ssh_duration)
  start_iso=$(date --iso-8601=ns); start_ms=$(now_ms)
  if timeout "$((duration + 15))" sshpass -p training-only ssh -b "$src" \
      -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 \
      labadmin@192.168.50.20 \
      "printf '%s\\n' '$tag' >/home/labadmin/upload/${tag}.txt; sleep '$duration'; rm -f /home/labadmin/upload/${tag}.txt" \
      >/dev/null 2>&1; then ok=true; else ok=false; fi
  end_ms=$(now_ms); end_iso=$(date --iso-8601=ns)
  record_event "$event_id" "$event_id" ssh 192.168.50.20 "$ok" "$start_iso" "$end_iso" \
    "$((end_ms - start_ms))" "${#tag}" 0 "requested_session_seconds=${duration}"
}

sample_ftp_size() {
  local roll
  roll=$(random_between 1 1000)
  if (( roll <= FTP_CDF_SMALL )); then random_between "$FTP_SMALL_MIN_BYTES" "$FTP_SMALL_MAX_BYTES"
  elif (( roll <= FTP_CDF_MEDIUM )); then random_between "$FTP_MEDIUM_MIN_BYTES" "$FTP_MEDIUM_MAX_BYTES"
  elif (( roll <= FTP_CDF_LARGE )); then random_between "$FTP_LARGE_MIN_BYTES" "$FTP_LARGE_MAX_BYTES"
  else random_between "$FTP_RARE_MIN_BYTES" "$FTP_MAX_BYTES"
  fi
}

ftp_transfer_inner() {
  local requested=$1 direction event_id remote_name actual timeout_seconds tmp output bytes seconds
  local start_iso end_iso start_ms end_ms ok
  event_id=$(new_id ftp); timeout_seconds=$((60 + requested / 2000000))
  (( timeout_seconds > 1800 )) && timeout_seconds=1800
  start_iso=$(date --iso-8601=ns); start_ms=$(now_ms)

  if [[ "$direction" == upload ]]; then
    tmp=$(mktemp /var/tmp/bluemon-upload.XXXXXX)
    truncate -s "$requested" "$tmp"
    remote_name="${event_id}.bin"
    output=$(curl --interface "$src" -sS --max-time "$timeout_seconds" \
      -u labadmin:training-only -T "$tmp" -w '%{size_upload} %{time_total}' \
      "ftp://192.168.50.20/upload/${remote_name}" 2>/dev/null || true)
    rm -f "$tmp"
    read -r bytes seconds <<<"${output:-0 0}"
    [[ "${bytes:-0}" -eq "$requested" ]] && ok=true || ok=false
    curl --interface "$src" -sS --max-time 10 -u labadmin:training-only \
      -Q "DELE /upload/${remote_name}" ftp://192.168.50.20/ >/dev/null 2>&1 || true
    actual=${bytes:-0}
  else
    remote_name=2GiB.bin
    actual=$requested
    output=$(curl --interface "$src" -sS --max-time "$timeout_seconds" \
      -u labadmin:training-only --range "0-$((requested - 1))" \
      -o /dev/null -w '%{size_download} %{time_total}' \
      "ftp://192.168.50.20/downloads/${remote_name}" 2>/dev/null || true)
    read -r bytes seconds <<<"${output:-0 0}"
    [[ "${bytes:-0}" -eq "$actual" ]] && ok=true || ok=false
  fi

  end_ms=$(now_ms); end_iso=$(date --iso-8601=ns)
  if [[ "$direction" == upload ]]; then
    record_event "$event_id" "$event_id" ftp 192.168.50.20 "$ok" "$start_iso" "$end_iso" \
      "$((end_ms - start_ms))" "${bytes:-0}" 0 "direction=upload requested_bytes=${requested} file=${remote_name}"
  else
    record_event "$event_id" "$event_id" ftp 192.168.50.20 "$ok" "$start_iso" "$end_iso" \
      "$((end_ms - start_ms))" 0 "${bytes:-0}" "direction=download requested_bytes=${requested} file=${remote_name} range_end=$((requested - 1))"
  fi
}

ftp_transfer() {
  local requested direction
  requested=$(sample_ftp_size)
  (( $(random_between 1 100) <= FTP_UPLOAD_PERCENT )) && direction=upload || direction=download
  if (( requested > FTP_LARGE_MAX_BYTES )); then
    flock -x "$large_lock" bash -c \
      'source /etc/default/elk-lab-benign; exec /opt/elk-lab/benign-worker.sh --ftp-child "$@"' \
      bash "$client_id" "$src" "$requested" "$direction"
  else
    ftp_transfer_inner "$requested" "$direction"
  fi
}

if [[ "$mode" == --ftp-child ]]; then
  ftp_transfer_inner "$child_ftp_size" "$child_ftp_direction"
  exit
fi

while true; do
  roll=$(random_between 1 "$WEIGHT_TOTAL")
  if [[ "${FORCE_PROTOCOL:-}" == web ]] || { [[ -z "${FORCE_PROTOCOL:-}" ]] && (( roll <= WEB_WEIGHT )); }; then
    web_session
  elif [[ "${FORCE_PROTOCOL:-}" == ssh ]] || { [[ -z "${FORCE_PROTOCOL:-}" ]] && (( roll <= WEB_WEIGHT + SSH_WEIGHT )); }; then
    ssh_session
  else
    ftp_transfer
  fi
  sleep "$(random_between "$THINK_MIN_SECONDS" "$THINK_MAX_SECONDS")"
done
