[README](README.md) | Introduction ➭ | [Setup](Setup.md) | [Tasks](Tasks.md) | [AI Use](AI-Use.md) | [Grading](Grading.md)

# Introduction and Rules

## Scenario

You are the security engineering team for a small organization that has recently centralized its logs. Management wants evidence that the monitoring system can reveal attacks and support safe, timely response. Activity is continuous, sources change addresses, and some adversarial sources deliberately mix ordinary requests with attacks.

Your task is not to label a list of addresses as good or bad. Your task is to identify and defend against **behaviors**.

## Network and trust zones

| Node | Zone and primary address | Purpose | Typical evidence |
|---|---|---|---|
| `gateway` | Four routed interfaces | Choke point and enforcement boundary | packet metadata, firewall decisions |
| `elk` | `192.168.50.10/24` | Elasticsearch, Logstash, Kibana | normalized events, dashboards, alerts |
| `webserver` | `10.10.10.10/8` | HTTP, DNS, and SSH service | access, DNS query, authentication logs |
| `fileserver` | `192.168.50.20/24` | SSH/SCP and FTP service | authentication and transfer logs |
| `client` | `172.16.1.2/16` plus aliases | Continuous legitimate activity | Web, DNS, administration, transfers |
| `attacker` | `172.17.1.2/16` plus aliases | Baseline and student-designed attacks | scan, credential, and Web behaviors |

The client and attacker each claim addresses dynamically from their own `/16`. The Web/DMZ side uses a broad `/8`, following the topology pattern used in the reference CTF. The gateway routes between every zone, making it the correct location for network-wide monitoring and mitigation.

## Why multiple IP addresses matter

A rule such as “block the attacker node's primary IP” is both trivial and ineffective. In this exercise:

- legitimate activity comes from many client aliases;
- attacks come from many attacker aliases;
- an attacker alias may alternate between normal and malicious requests;
- new aliases may appear after your detection is deployed; and
- mitigation is graded on both attack reduction and legitimate availability.

Useful detections therefore rely on rates, sequences, failures, destination diversity, unusual paths, or combinations of signals over a time window.

## Team organization

Teams contain six to eight students. Assign a primary owner and a reviewer for every workstream. A student may cover two adjacent roles, but no role may operate without peer review.

| Role | Primary responsibility |
|---|---|
| Platform engineer | ELK deployment, health, persistence, and access |
| Endpoint telemetry engineer | system, authentication, Web, DNS, and file-service logs |
| Network telemetry engineer | gateway visibility, flow/packet metadata, time synchronization |
| Benign workload engineer | validate and extend legitimate workload coverage |
| Adversary emulation engineer | design safe additional attacks and ground truth |
| Detection engineer | queries, rules, alerts, dashboards, and tuning |
| Response engineer | firewall/access controls, rollback, and availability validation |
| Validation lead | experiment plan, metrics, evidence integrity, and final demonstration |

Every member must be able to explain the complete data path from an action on a source node to an indexed event, alert, and response decision.

## Rules of engagement

1. Only attack addresses and services inside your assigned SPHERE experiment.
2. Do not attack another team, the SPHERE infranet, the XDC, or Internet hosts.
3. Keep tests bounded. Resource exhaustion, destructive payloads, persistence, and denial of service are out of scope.
4. Do not erase, disable, or tamper with the baseline workload or its ground-truth records.
5. Do not solve the task with a permanent block of the attacker subnet.
6. Before changing gateway rules, save the current rules and prepare a timed rollback.
7. Record the exact time, source aliases, targets, and intended behavior for every student-designed test.
8. AI assistance is permitted only under [AI Use and Evidence](AI-Use.md).

## Success criteria

A successful solution demonstrates that all required telemetry reaches ELK, benign and adversarial behaviors can be reconstructed, detections generalize to unseen aliases, precision and recall come from ground truth, mitigation reduces attacks, and legitimate HTTP, DNS, SSH, and file-transfer checks continue to pass.

