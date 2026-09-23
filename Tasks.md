[README](README.md) | [Introduction](Introduction.md) | [Setup](Setup.md) | Tasks ➭ | [AI Use](AI-Use.md) | [Grading](Grading.md)

# Tasks and Milestones

## Week 1 — Monitoring setup

### Task 1.1: Deploy ELK

Deploy Elasticsearch, Logstash, and Kibana on `elk`. You may use native packages or containers, but the deployment must survive a service restart, bind only where needed, report healthy status, use a documented version, retain data for the assignment, and have a documented recovery procedure.

Do not commit credentials. If you disable a security feature because the experiment is isolated, document why the same choice would be inappropriate in production.

### Task 1.2: Build a telemetry coverage matrix

Collect at least:

| Source | Required evidence |
|---|---|
| `gateway` | connection or packet metadata and firewall decisions |
| `webserver` | Web access/error, DNS query, and SSH authentication logs |
| `fileserver` | SSH authentication and file-transfer logs |
| `client` | workload execution status and service-check outcomes |
| all monitored nodes | host identity and reliable timestamps |

For each source, record its producer, shipper, transport, index/data stream, timestamp field, parsing status, and owner. Events do not count as parsed if important fields exist only inside `message`.

### Task 1.3: Validate data quality

Run one uniquely tagged action per required protocol. Locate it in Kibana and preserve evidence linking:

`action → source log → shipped event → parsed fields → dashboard result`

Check clock skew, duplicates, ingestion delay, field types, direction, and gaps. State and justify an acceptable ingestion-delay threshold.

### Task 1.4: Create operational dashboards

Create:

1. **Service health:** request success/failure, authentication outcomes, log volume, and freshness.
2. **Security overview:** top aliases, destination ports, failed logins, Web paths/statuses, scan-like behavior, and firewall actions.

Every visualization must answer a written operational question.

### Week 1 milestone

Demonstrate healthy ELK, all mandatory sources, one end-to-end trace per protocol, a completed coverage matrix, and the service-health dashboard. Submit `week1.md`, exported dashboard objects, sanitized configuration, and evidence.

---

## Week 2 — Detection and investigation

### Task 2.1: Characterize normal activity

Observe at least 30 minutes of legitimate workload before tuning on attacks. Quantify normal request rate, unique aliases, destination ports, authentication failures, and common paths. Identify two benign behaviors that could resemble attacks.

### Task 2.2: Investigate the supplied baseline

Without first reading attacker ground truth, reconstruct a port scan, repeated SSH failures, and Web reconnaissance. For each, produce a timeline with aliases, targets, fields, and queries. Then compare with ground truth and document misses.

### Task 2.3: Design three additional attacks

Create three safe, bounded scenarios:

1. one network/service-discovery behavior;
2. one authentication or credential behavior; and
3. one Web or application behavior.

At least one must rotate across five source aliases. At least one alias must also perform benign-looking activity. At least one scenario must differ materially from the baseline.

Document the hypothesis, ATT&CK mapping where applicable, scope, maximum rate, rollback, expected evidence, and JSONL ground truth. Obtain peer review before execution.

### Task 2.4: Implement and tune detections

Implement five or more detections: three required attack families, one correlation using two telemetry sources, and one behavior-based rule that works for unseen aliases.

Each specification must include purpose, required fields, logic, threshold/window, benign lookalikes, severity, response guidance, a positive test, and a negative test.

### Task 2.5: Measure detection quality

Freeze a rule before reading test-run ground truth. Use at least ten attack and ten benign labeled windows. Report a confusion matrix and calculate:

```text
precision = TP / (TP + FP)
recall    = TP / (TP + FN)
F1        = 2 × precision × recall / (precision + recall)
```

Explain each false result, tune once, and report before/after results. Do not delete inconvenient windows.

### Week 2 milestone

Demonstrate one supplied and one student-designed attack from action through alert. Submit attack specifications/scripts, ground truth, rule specifications/exports, evaluation data, and `week2.md`.

---

## Week 3 — Mitigation and validation

### Task 3.1: Design a safe response

Choose two detected behaviors and define mitigations. One must operate at `gateway`; the other may use a host firewall, service setting, rate control, or account policy.

Specify trigger evidence, scope/expiration, exceptions, collateral impact, audit logging, timed rollback, and recovery if access is lost. A permanent block of `172.17.0.0/16` does not qualify.

### Task 3.2: Implement behavior-based control

Implement a control that handles changing aliases, such as a short-lived dynamic set after repeated failures, rate limits, service-specific blocking, or a correlation-driven response. It must be explainable and inspectable.

### Task 3.3: Run a controlled before/after experiment

Use the same seed, duration, attacks, and service checks before and after mitigation. Report attacks and outcomes, mean time to detect/mitigate, legitimate success by protocol, false blocks/duration, resource use, and unseen-alias handling.

### Task 3.4: Adversarial validation

Exchange **scenario descriptions only** with another team or use an instructor holdout. Do not attack another team. Reproduce the scenario inside your own experiment and evaluate generalization.

### Task 3.5: Final demonstration

In 12 minutes, show topology and telemetry health; run one bounded attack with changing aliases; trace it into an alert; show mitigation and expiration/rollback; and prove legitimate services still work. Conclude with one success, one failure, and one production improvement.

### Week 3 milestone

Submit the package in [Grading](Grading.md) and complete an individual explanation check.

