#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

while IFS= read -r -d '' script; do
  bash -n "$script"
done < <(find "$repo/sphere" -type f \( -name install -o -name '*.sh' \) -print0)

python3 -m json.tool "$repo/profiles/mawi-samplepoint-f-2025.json" >/dev/null

# shellcheck disable=SC1091
source "$repo/sphere/client/traffic-profile.env"
(( WEB_WEIGHT + SSH_WEIGHT + FTP_WEIGHT == WEIGHT_TOTAL ))
(( CLIENT_COUNT == 8 ))
(( FTP_MAX_BYTES == 2147483648 ))
(( SSH_CDF_SHORT <= SSH_CDF_MEDIUM ))
(( SSH_CDF_MEDIUM <= SSH_CDF_LONG ))
(( FTP_CDF_SMALL <= FTP_CDF_MEDIUM ))
(( FTP_CDF_MEDIUM <= FTP_CDF_LARGE ))

python3 - "$repo/profiles/mawi-samplepoint-f-2025.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    profile = json.load(handle)
counts = profile["totals"]["packets"]
assert counts["web"] + counts["ssh"] + counts["ftp"] == counts["all_selected"]
weights = profile["totals"]["basis_points"]
assert weights["web"] + weights["ssh"] + weights["ftp"] == weights["total"] == 10000
PY

echo 'PASS static workload checks'
