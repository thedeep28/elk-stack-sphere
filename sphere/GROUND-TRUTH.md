# Ground-truth records

The baseline emits one JSON object per completed workload episode.

Attack records contain `@timestamp`, `event.end`, `event.id`, `traffic.class`, `attack.behavior`, `source.ip`, `destination.ip`, and `bounded`.

Benign records contain `@timestamp`, `event.id`, `traffic.class`, `network.protocol`, `source.ip`, `destination.ip`, `event.success`, and `detail`.

Students should use independent service and gateway telemetry to build detections. Ground truth labels evaluation windows after a rule is frozen; it is not a production signal and must not be ingested as one.

