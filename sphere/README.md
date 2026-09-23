# SPHERE private-lab package

Copy this directory's contents into the class organization's private-material folder for lab `elkdefense`. The layout follows SPHERE's `runlab` convention: `elkdefense.model`, `nodes`, and one directory per configured node.

Before class use:

1. Confirm `bullseye` is an available image; change all model entries together if needed.
2. Make every `install` and shell script executable.
3. Run `mrg compile elkdefense.model`.
4. Materialize an instructor copy with `startexp`.
5. Attach an XDC and run `validate-lab.sh`.
6. Observe traffic and timer load for at least 30 minutes.

The setup deliberately does **not** deploy ELK or data shippers. Those are student learning tasks. It creates the topology, services, alias pools, benign activity, bounded attack baseline, and local ground truth.

Baseline ground truth is written on `attacker` to `/var/log/elk-lab/attacks.jsonl`. Benign workload results are written on `client` to `/var/log/elk-lab/benign.jsonl`.
