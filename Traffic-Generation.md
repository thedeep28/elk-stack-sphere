[README](README.md) | [Setup](Setup.md) | Traffic generation | [Tasks](Tasks.md)

# Traffic generation and ground truth

BlueMon starts two independent workloads during `runlab`: continuous benign traffic on `client` and a bounded, periodic attack campaign on `attacker`. Both use IP aliases so that students must detect behavior rather than memorize one address.

## Benign workload

`elk-lab-benign.service` runs one orchestrator and eight long-lived workers. Worker 1 uses `172.16.10.10`, worker 2 uses `.11`, and so on through `.17`. Each worker independently selects and completes an interaction, pauses for 5–25 seconds, and selects again. A long SSH or FTP interaction therefore does not stop the other clients.

The default selection weights are:

| Interaction | Weight | Generated behavior |
|---|---:|---|
| Web | 92.16% | DNS lookup followed by a 2–8-request HTTP session with varied paths and user agents |
| SSH | 7.54% | Successful login to `fileserver`, a small administrative write, and a 1–300 second connected session |
| FTP | 0.30% | Authenticated upload or download, selected 50/50, from 64 KiB through 2 GiB |

These weights are normalized IPv4+IPv6 packet counts for HTTP, SSH, and FTP from four official MAWI Samplepoint-F summaries: `202501011400`, `202504091400`, `202507011400`, and `202510011400`. The exact source counts and URLs are stored in [`profiles/mawi-samplepoint-f-2025.json`](profiles/mawi-samplepoint-f-2025.json). Run the reproducible miner with:

```bash
python3 tools/mine-mawi-summaries.py
```

This is an empirical protocol mix, not a claim that packet proportions equal session proportions. The public summary pages do not contain per-flow duration or file-size distributions, so the SSH and FTP buckets are explicit, provisional lab parameters. They are deliberately visible in `sphere/client/traffic-profile.env` and can be replaced after flow-level trace analysis.

SSH duration is sampled from four buckets: 65% at 1–5 seconds, 25% at 6–30 seconds, 9% at 31–120 seconds, and 1% at 121–300 seconds. FTP size is heavy-tailed: 70% at 64 KiB–4 MiB, 25% above 4–64 MiB, 4.5% above 64–512 MiB, and 0.5% above 512 MiB–2 GiB. Only one transfer above 512 MiB runs at once. Downloads use an exact-length byte range from a sparse 2 GiB object; uploads use a temporary sparse source and are deleted remotely after completion. Both produce the sampled number of application bytes on the network without permanently consuming that much disk.

To change the profile on a running client, edit `/etc/default/elk-lab-benign`, keep the three protocol weights equal to `WEIGHT_TOTAL`, then run:

```bash
sudo systemctl restart elk-lab-benign.service
```

Use `FORCE_PROTOCOL=web`, `ssh`, or `ftp` only for an instructor smoke test. Remove it for normal student activity.

## Attack campaign

`elk-lab-attack.timer` starts a campaign about every five minutes, with up to 60 seconds of randomized delay. Each campaign chooses three distinct addresses from `172.17.20.10–29` and runs four bounded workers in parallel:

- a low-rate TCP scan of ports 21, 22, 53, 80, and 443;
- four failed SSH password guesses, separated by two seconds;
- six Web-enumeration requests, separated by two seconds; and
- ordinary-looking HTTP cover requests from all three attack aliases.

The targets are hard-coded to the two lab services and each worker checks the target before acting. Campaigns do not include denial of service, persistence, destructive payloads, or external targets.

Check whether a campaign is active and see its latest actions with:

```bash
ssh attacker 'sudo attack-status'
```

For an immediate controlled run:

```bash
ssh attacker 'sudo systemctl start elk-lab-attack.service'
```

The service is non-overlapping: systemd will not start a second copy while one is active.

## Ground truth

Benign records are appended to `/var/log/elk-lab/benign.jsonl` on `client`. Every DNS request, HTTP request, SSH session, and FTP transfer has start/end timestamps, event and parent IDs, source/destination, success, elapsed milliseconds, application bytes observed by the generator, and protocol-specific detail. Requests in one Web session share `event.parent_id`. These byte fields are not packet-capture wire-byte counters; use gateway flow telemetry when Ethernet/IP/TCP overhead matters.

Attack records are appended to `/var/log/elk-lab/attacks.jsonl` on `attacker`. The file contains campaign start/end markers and one record for each scanned port, password attempt, enumeration request, and cover request. Action records contain campaign/event IDs, behavior, action, source/destination/port, outcome, duration, and detail. Current campaign state is also written to `/run/elk-lab/attack-active.json`.

These files are evaluation labels, not detection inputs. Students should build rules from gateway and service telemetry, freeze a rule, and only then compare its output with ground truth.

## Operational checks

```bash
ssh client 'systemctl is-active elk-lab-benign.service; pgrep -af benign-worker.sh'
ssh client 'sudo tail -n 10 /var/log/elk-lab/benign.jsonl | jq .'
ssh attacker 'systemctl is-active elk-lab-attack.timer; sudo attack-status'
```

If the class testbed has limited bandwidth, reduce the FTP bucket bounds before deployment. A 2 GiB maximum is supported, not a guarantee that every class should use that maximum concurrently.
