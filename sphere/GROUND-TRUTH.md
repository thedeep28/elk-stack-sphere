# Ground-truth records

The baseline emits one JSON object per completed action, plus attack campaign boundary records.

Attack action records contain `@timestamp`, `event.end`, `campaign.id`, `event.id`, `traffic.class`, `attack.behavior`, `event.action`, `source.ip`, `destination.ip`, `destination.port`, `event.outcome`, `event.duration_ms`, `detail`, and `bounded`. Campaign markers contain `campaign.id`, `event.kind=campaign`, and `event.action=campaign_start|campaign_end`. The live state file is `/run/elk-lab/attack-active.json`; `sudo attack-status` displays it with recent actions.

Benign records contain `@timestamp`, `event.end`, `event.id`, `event.parent_id`, `client.id`, `traffic.class`, `network.protocol`, `source.ip`, `destination.ip`, `event.success`, `event.duration_ms`, `source.bytes`, `destination.bytes`, and `detail`. HTTP requests from one Web session share a parent ID.

Students should use independent service and gateway telemetry to build detections. Ground truth labels evaluation windows after a rule is frozen; it is not a production signal and must not be ingested as one.
