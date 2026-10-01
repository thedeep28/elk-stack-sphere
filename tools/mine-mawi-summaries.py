#!/usr/bin/env python3
"""Regenerate BlueMon protocol weights from official MAWI summary pages."""

from __future__ import annotations

import argparse
import json
import re
import sys
import urllib.request
from datetime import date

DEFAULT_TRACES = (
    "202501011400",
    "202504091400",
    "202507011400",
    "202510011400",
)
PROTOCOL_RE = re.compile(r"^\s+(http|ssh|ftp)\s+(\d+)\s+", re.MULTILINE)


def fetch_trace(trace_id: str) -> dict[str, object]:
    year = trace_id[:4]
    url = (
        "https://mawi.nezu.wide.ad.jp/mawi/samplepoint-F/"
        f"{year}/{trace_id}.html"
    )
    request = urllib.request.Request(url, headers={"User-Agent": "BlueMon-profile-miner/1.0"})
    with urllib.request.urlopen(request, timeout=30) as response:
        page = response.read().decode("utf-8", errors="replace")

    packets = {"web": 0, "ssh": 0, "ftp": 0}
    for protocol, count in PROTOCOL_RE.findall(page):
        key = "web" if protocol == "http" else protocol
        packets[key] += int(count)
    if not all(packets.values()):
        raise RuntimeError(f"missing protocol data in {url}: {packets}")
    return {"id": trace_id, "url": url, "packets": packets}


def build_profile(trace_ids: list[str]) -> dict[str, object]:
    traces = [fetch_trace(trace_id) for trace_id in trace_ids]
    totals = {protocol: 0 for protocol in ("web", "ssh", "ftp")}
    for trace in traces:
        for protocol, count in trace["packets"].items():
            totals[protocol] += count
    selected_total = sum(totals.values())
    percentages = {
        protocol: round(count / selected_total * 100, 6)
        for protocol, count in totals.items()
    }
    basis_points = {
        protocol: round(count / selected_total * 10000)
        for protocol, count in totals.items()
    }
    basis_points["web"] += 10000 - sum(basis_points.values())
    return {
        "profile_id": "mawi-samplepoint-f-summary-profile",
        "generated_at": date.today().isoformat(),
        "method": "Combined IPv4 and IPv6 packet counts from official MAWI protocol summary pages, normalized across plain HTTP, SSH, and FTP.",
        "traces": traces,
        "totals": {
            "packets": {**totals, "all_selected": selected_total},
            "percent": percentages,
            "basis_points": {**basis_points, "total": 10000},
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("trace_ids", nargs="*", default=list(DEFAULT_TRACES))
    parser.add_argument("-o", "--output", help="write JSON to this path instead of stdout")
    args = parser.parse_args()
    profile = json.dumps(build_profile(args.trace_ids), indent=2) + "\n"
    if args.output:
        with open(args.output, "w", encoding="utf-8") as handle:
            handle.write(profile)
    else:
        sys.stdout.write(profile)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
