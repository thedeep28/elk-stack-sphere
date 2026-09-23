[README](README.md) | [Introduction](Introduction.md) | [Setup](Setup.md) | [Tasks](Tasks.md) | [AI Use](AI-Use.md) | Grading ➭

# Submission and Grading

## Final submission

Submit one repository or archive containing:

```text
submission/
├── README.md
├── architecture/
├── config/
├── dashboards/
├── detections/
├── attacks/
├── ground-truth/
├── evaluation/
├── evidence/week1|week2|week3/
├── ai/AI-ledger.md
├── team-contributions.md
└── final-report.md
```

Do not submit passwords, tokens, keys, packet captures containing credentials, ELK data directories, or generated dependency trees.

## Rubric (100 points)

| Area | Points | Full-credit evidence |
|---|---:|---|
| Reproducible ELK deployment | 10 | Healthy, restartable, versioned, documented, recoverable |
| Telemetry coverage and quality | 15 | All sources; parsed fields; timestamps, delay, gaps, duplicates validated |
| Dashboards and investigation | 10 | Operational questions answered; baseline reconstructed with timelines |
| Student-designed attacks | 10 | Three safe, distinct, reviewed scenarios with aliases and ground truth |
| Detection engineering | 15 | Five rules including correlation and unseen-alias behavior detection |
| Detection evaluation | 10 | Labeled trials, confusion matrix, precision/recall/F1, tuning comparison |
| Mitigation engineering | 15 | Scoped dynamic controls, audit, expiration, rollback, no subnet shortcut |
| Availability and validation | 5 | Attacks reduced while legitimate protocols remain usable |
| Documentation/reproducibility | 5 | Another team can reproduce key results |
| Individual contribution/AI verification | 5 | Peer-confirmed contribution and explained AI-assisted artifact |

## Team and individual grading

The shared result determines 85 points. Documentation/reproducibility, contribution evidence, and AI verification may vary by individual. A shared artifact does not prove that every member understands it.

## Automatic caps

- Out-of-scope or destructive activity: refer to instructor; may receive no credit.
- Permanent attacker-subnet block: mitigation capped at 5/15.
- Missing ground truth or fabricated evaluation: evaluation receives 0/10.
- Logs present but mandatory fields unparsed: telemetry capped at 7/15.
- Undisclosed or unexplained AI-generated artifact: affected artifact at most half credit.

