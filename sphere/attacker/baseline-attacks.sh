#!/usr/bin/env bash
set -uo pipefail

log=/var/log/elk-lab/attacks.jsonl
iface=$(ip -o -4 addr show | awk '$4 ~ /^172\.17\.1\.2\// {print $2; exit}')
src="172.17.20.$((10 + RANDOM % 20))"
event_id="attack-$(date +%s)-${RANDOM}"
mode=$(( $(date +%s) / 180 % 3 ))
start=$(date --iso-8601=seconds)

guard_target() {
  case "$1" in
    10.10.10.10|192.168.50.20) return 0 ;;
    *) echo "Refusing non-lab target: $1" >&2; return 1 ;;
  esac
}

case "$mode" in
  0)
    behavior=port_scan
    target=10.10.10.10
    guard_target "$target" || exit 2
    timeout 30 nmap -n -Pn -sS -T3 --max-rate 20 -p 21,22,53,80,443 \
      -S "$src" -e "$iface" "$target" >/dev/null 2>&1 || true
    ;;
  1)
    behavior=ssh_password_guessing
    target=192.168.50.20
    guard_target "$target" || exit 2
    for password in password admin123 letmein welcome; do
      timeout 6 sshpass -p "$password" ssh -b "$src" \
        -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o ConnectTimeout=3 labadmin@"$target" true >/dev/null 2>&1 || true
      sleep 2
    done
    ;;
  *)
    behavior=web_enumeration
    target=10.10.10.10
    guard_target "$target" || exit 2
    for path in admin login private backup .git/config robots.txt; do
      curl --interface "$src" -sS -o /dev/null --max-time 5 \
        -A 'BlueMon-baseline-enumerator/1.0' "http://${target}/${path}" || true
      sleep 2
    done
    ;;
esac

# The same adversary alias also looks ordinary, defeating permanent bad-IP labels.
curl --interface "$src" -sS -o /dev/null --max-time 5 \
  -A 'Mozilla/5.0 BlueMon mixed-source' "http://10.10.10.10/" || true

jq -nc --arg ts "$start" --arg end "$(date --iso-8601=seconds)" \
  --arg id "$event_id" --arg behavior "$behavior" --arg src "$src" --arg dst "$target" \
  '{"@timestamp":$ts,"event.end":$end,"event.id":$id,"traffic.class":"attack","attack.behavior":$behavior,"source.ip":$src,"destination.ip":$dst,"bounded":true}' \
  >>"$log"
