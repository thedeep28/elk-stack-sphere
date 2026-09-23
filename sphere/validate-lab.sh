#!/usr/bin/env bash
set -euo pipefail

nodes=(gateway elk webserver fileserver client attacker)
failed=0

for node in "${nodes[@]}"; do
  if ssh -o BatchMode=yes -o ConnectTimeout=5 "$node" true; then
    printf 'PASS ssh %s\n' "$node"
  else
    printf 'FAIL ssh %s\n' "$node"
    failed=1
  fi
done

ssh client curl -fsS --max-time 5 http://10.10.10.10/ >/dev/null \
  && printf 'PASS HTTP client -> webserver\n' \
  || { printf 'FAIL HTTP client -> webserver\n'; failed=1; }

ssh client dig +short +time=2 +tries=1 @10.10.10.10 portal.corp.test \
  | grep -qx '10.10.10.10' \
  && printf 'PASS DNS client -> webserver\n' \
  || { printf 'FAIL DNS client -> webserver\n'; failed=1; }

if [[ "$(ssh gateway /usr/sbin/sysctl -n net.ipv4.ip_forward)" == 1 ]]; then
  printf 'PASS gateway forwarding\n'
else
  printf 'FAIL gateway forwarding\n'
  failed=1
fi

exit "$failed"
