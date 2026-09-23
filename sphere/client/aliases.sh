#!/usr/bin/env bash
set -euo pipefail

iface=$(ip -o -4 addr show | awk '$4 ~ /^172\.16\.1\.2\// {print $2; exit}')
if [[ -z "${iface:-}" ]]; then
  echo 'Could not find the SPHERE interface for 172.16.1.2' >&2
  exit 1
fi

sysctl -w "net.ipv4.conf.${iface}.rp_filter=0" >/dev/null
for host in $(seq 10 29); do
  ip address add "172.16.10.${host}/16" dev "$iface" 2>/dev/null || true
done

