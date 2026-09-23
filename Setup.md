[README](README.md) | [Introduction](Introduction.md) | Setup ➭ | [Tasks](Tasks.md) | [AI Use](AI-Use.md) | [Grading](Grading.md)

# Setup and Access

## 1. Create and configure the experiment

Follow your instructor's SPHERE account instructions and open a terminal in your class XDC. Create one complete instance of the lab with:

```bash
startexp elkdefense
runlab elkdefense
```

Your instructor publishes the class lab materials and assigns the correct project. `startexp` creates the complete six-node topology in one operation. After it reports completion, `runlab` copies the per-node files and runs each node's installation script. Provisioning may take several minutes. If `runlab` appears finished but does not return to the prompt, press Enter once, as described in the SPHERE class guide.

Do not run `startexp` repeatedly because an install appears quiet. First inspect experiment status and `/var/log/elk-lab-install.log` on the affected node.

## 2. Attach and connect

Attach your team XDC to the realization created for your team. Verify name resolution and SSH access:

```bash
getent hosts gateway elk webserver fileserver client attacker
ssh gateway hostname
ssh elk hostname
```

Use experiment node names, not infranet addresses, in normal lab work. Attacks and measurements belong only on the experiment network.

## 3. Validate the topology

On each node, record interfaces, addresses, and routes:

```bash
ip -brief address
ip route
```

| Link | Gateway | Other node(s) |
|---|---|---|
| DMZ | `10.0.0.1/8` | `webserver: 10.10.10.10/8` |
| Legitimate client | `172.16.0.1/16` | `client: 172.16.1.2/16` |
| Adversary | `172.17.0.1/16` | `attacker: 172.17.1.2/16` |
| SOC/internal | `192.168.50.1/24` | `elk: .10`, `fileserver: .20` |

On `gateway`, `sysctl net.ipv4.ip_forward` must return `1`.

## 4. Validate services and workloads

From `client`:

```bash
curl --interface 172.16.10.10 http://10.10.10.10/
dig @10.10.10.10 portal.corp.test
systemctl status elk-lab-benign.timer --no-pager
```

From `attacker`:

```bash
systemctl status elk-lab-attack.timer --no-pager
```

Do not use the attacker ground-truth log as a detection source. It exists for validation after a rule is frozen.

## 5. Record a pre-change baseline

Before installing agents or changing firewall rules, capture interfaces, routes, listening services, gateway firewall state, time synchronization, and five minutes of service checks. Store the output in `evidence/week1/pre-change/`.

## If setup fails

1. Identify the failing node and inspect `/var/log/elk-lab-install.log`.
2. Confirm `/tmp/<node>/install` exists and is executable.
3. Verify Internet access through the infranet before blaming experiment links.
4. Do not change the SPHERE control interface or default route.
5. Include the failing command and relevant log excerpt when asking for help.
