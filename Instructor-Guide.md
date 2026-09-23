# Instructor Guide: BlueScope

This file is for instructors and teaching assistants. Remove it from a student release if it contains local details or holdouts.

## Design intent

BlueScope is a three-week, six-to-eight-person assignment emphasizing ELK operations, evidence-based detection, dynamic mitigation, and critical AI use. Automation creates a reproducible floor. Students must design new attacks, explain observables, build detections, and measure results.

## SPHERE deployment

The private-lab source is `sphere/`:

- lab name: `elkdefense`;
- model: `elkdefense.model`;
- configured nodes: `nodes`; and
- one folder per node with executable `install` and supporting files.

Students create and configure the experiment with:

```bash
startexp elkdefense
runlab elkdefense
```

Before release, validate with `mrg compile`, instantiate an instructor copy, and run `sphere/validate-lab.sh` from an attached XDC. A research-project smoke test successfully compiled and materialized all six nodes, completed all per-node installation scripts, and passed the baseline SSH, HTTP, DNS, and gateway-forwarding validator. The remaining workload observation was interrupted when SPHERE facility hosts went offline and the materialization returned to `Pending`; repeat the complete smoke test on healthy infrastructure before student release.

## Resource planning

The `elk` node requests more memory and CPU. Confirm image names and capacity with SPHERE operations. If concurrent copies exceed allocation, shorten retention or schedule teams. Do not collapse the topology without revising objectives.

## Schedule

| Meeting | Instructor activity | Checkpoint |
|---|---|---|
| Before Week 1 | Materialize smoke test; verify packages/timers | None |
| Week 1 start | Brief topology, rules, AI evidence | Roles and baseline |
| Week 1 end | Data-quality review | Matrix and dashboards |
| Week 2 middle | Detection clinic | Attack specs reviewed before execution |
| Week 2 end | Freeze and evaluate rules | Raw labeled data retained |
| Week 3 start | Firewall safety and rollback drill | Response approval |
| Week 3 end | Holdout and demonstration | Package and individual checks |

## Holdout ideas

Keep exact parameters private. Suitable low-rate, non-destructive holdouts include a slow distributed scan, password spraying, Web enumeration interleaved with successful requests, an alias that attacks briefly between benign periods, or changed paths/user agents preserving the underlying behavior.

## Evaluation guidance

Evaluate labeled behavior windows, not raw alert counts. Require teams to declare alert matching and deduplication before viewing holdout labels. Sample all legitimate protocols during before/after tests.

## AI learning checks

Select an AI-assisted artifact at random from each ledger. Ask the student to explain a parameter, predict a change, and make the change in a disposable copy.

## Validate before publication

1. Confirm that the `bullseye` image is available on the selected facility.
2. Confirm mirrors expose required packages.
3. Confirm every intended path traverses `gateway`.
4. Confirm aliases persist across workload runs.
5. Verify timer rates across simultaneous class copies.
6. Decide when attacker ground truth becomes visible.
7. Add class XDC, project, due date, and submission details.
