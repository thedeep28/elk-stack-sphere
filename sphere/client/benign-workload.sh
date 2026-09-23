#!/usr/bin/env bash
set -uo pipefail

log=/var/log/elk-lab/benign.jsonl
src="172.16.10.$((10 + RANDOM % 20))"
event_id="benign-$(date +%s)-${RANDOM}"
tag="${event_id}"

record() {
  local protocol=$1 destination=$2 success=$3 detail=$4
  jq -nc \
    --arg ts "$(date --iso-8601=seconds)" \
    --arg id "$event_id" --arg proto "$protocol" --arg src "$src" \
    --arg dst "$destination" --argjson ok "$success" --arg detail "$detail" \
    '{"@timestamp":$ts,"event.id":$id,"traffic.class":"benign","network.protocol":$proto,"source.ip":$src,"destination.ip":$dst,"event.success":$ok,"detail":$detail}' \
    >>"$log"
}

http_code=$(curl --interface "$src" -sS -o /dev/null -w '%{http_code}' --max-time 8 \
  "http://10.10.10.10/?request_id=${tag}" 2>/dev/null || true)
[[ "$http_code" == 200 ]] && record http 10.10.10.10 true "status=${http_code}" \
  || record http 10.10.10.10 false "status=${http_code:-none}"

dns_answer=$(dig -b "$src" +short +time=2 +tries=1 @10.10.10.10 portal.corp.test 2>/dev/null || true)
[[ "$dns_answer" == *10.10.10.10* ]] && record dns 10.10.10.10 true 'portal.corp.test' \
  || record dns 10.10.10.10 false 'portal.corp.test'

if sshpass -p training-only ssh -b "$src" -o StrictHostKeyChecking=no \
  -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 labadmin@192.168.50.20 \
  "printf '${tag}\\n' >/home/labadmin/upload/${tag}.txt" >/dev/null 2>&1; then
  record ssh 192.168.50.20 true "write=${tag}.txt"
else
  record ssh 192.168.50.20 false "write=${tag}.txt"
fi

tmp=$(mktemp)
printf 'BlueMon benign transfer %s\n' "$tag" >"$tmp"
if curl --interface "$src" -sS --max-time 8 -u labadmin:training-only \
  -T "$tmp" "ftp://192.168.50.20/upload/${tag}.txt" >/dev/null 2>&1; then
  record ftp 192.168.50.20 true "upload=${tag}.txt"
else
  record ftp 192.168.50.20 false "upload=${tag}.txt"
fi
rm -f "$tmp"
