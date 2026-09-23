# Instructor SPHERE Smoke Test

Use this checklist for the first instructor-only deployment. Do not release the assignment until all required checks pass.

## 0. Choose the deployment path

The student-facing class workflow is:

```bash
startexp elkdefense
runlab elkdefense
```

It expects the instructor-published lab under `/share/education/elkdefense`. Use the remaining instructions for a pre-publication test in a research project when `/share/education` is read-only. This development path stores the lab under `$HOME/organizations` and uses the installed `startexp` helper's `-p` and `-f` options.

## 1. Prerequisites

You need:

- a SPHERE project in which you may create experiments;
- a personal or shared XDC that can attach to that project;
- the `elk-stack-sphere/sphere/` directory available inside the XDC; and
- enough capacity for six nodes, including an ELK node requesting four cores and 16 GB RAM.

Use placeholders consistently below:

```bash
RESEARCH_PROJECT=replace-with-your-project
LAB=elkdefense
LABROOT="$HOME/organizations"
```

Do not paste a real password into a shared command transcript or Git repository.

## 2. Prepare the instructor XDC

In the SPHERE Launch portal:

1. Open **Projects** and confirm the intended test project.
2. Open **XDCs** and create a personal XDC or an XDC in that project if one does not exist.
3. Wait until its Jupyter link appears, open Jupyter, and open a Terminal.
4. If the prompt is `#`, switch to your SPHERE user with `su - YOUR_USERNAME`.
5. Confirm the class helper commands are available:

```bash
export PATH="$PATH:/share"
command -v startexp runlab stopexp mrg
```

## 3. Put the development lab in `$HOME/organizations`

Upload or clone the repository into the XDC. The directory installed for the private lab must look exactly like this:

```text
$HOME/organizations/elkdefense/
├── elkdefense.model
├── nodes
├── gateway/install
├── elk/install
├── webserver/install
├── fileserver/install
├── client/install ...
└── attacker/install ...
```

Copy the contents of this repository's `sphere/` directory—not the `sphere` directory itself—into `$HOME/organizations/elkdefense/`. For example, from the repository root:

```bash
SOURCE="$PWD/sphere"
mkdir -p "$HOME/organizations/elkdefense"
cp -a "$SOURCE"/. "$HOME/organizations/elkdefense/"
find "$HOME/organizations/elkdefense" -type f \( -name install -o -name '*.sh' \) -exec chmod a+rx {} +
```

Confirm the structure:

```bash
find "$HOME/organizations/elkdefense" -maxdepth 2 -type f | sort
cat "$HOME/organizations/elkdefense/nodes"
```

The `nodes` file must list exactly: `gateway`, `elk`, `webserver`, `fileserver`, `client`, and `attacker`.

## 4. Check the operating-system image

The model currently requests `bullseye`. Confirm that it is available and ready:

```bash
mrg list images --filter all | grep -E '^bullseye[[:space:]]'
```

If it is unavailable on the chosen facility, stop and select a supported Debian image. Update all six `image ==` constraints together and retest the install scripts against that OS. Model compilation alone does not verify image availability.

## 5. Run static checks inside the XDC

```bash
find "$HOME/organizations/elkdefense" -type f \( -name install -o -name '*.sh' \) \
  -print0 | xargs -0 -n1 bash -n

mrg compile "$HOME/organizations/elkdefense/elkdefense.model"
```

Do not continue if either command reports an error.

## 6. Create the six-node experiment

From the XDC, run:

```bash
startexp \
  -p "$RESEARCH_PROJECT" \
  -f "$LABROOT" \
  "$LAB"
```

Wait for `startexp` to report completion. This operation creates/materializes the entire topology; it does not run the per-node installation scripts.

If materialization fails, inspect the reported reason. Common first checks are image availability and the 16 GB memory constraint on `elk`.

After materialization succeeds, explicitly attach the XDC if `startexp` did not finish that step:

```bash
mrg xdc attach XDC_NAME.PROJECT "real.${LAB}.${RESEARCH_PROJECT}"
getent hosts gateway elk webserver fileserver client attacker
```

Do not continue until all names resolve and `ssh gateway hostname` succeeds.

## 7. Configure all nodes

The shared `/share/runlab` helper reads only `/share/education`. For this research-project smoke test, create a user-local copy that reads `$HOME/organizations` while preserving the command interface:

```bash
mkdir -p "$HOME/bin"
cp /share/runlab "$HOME/bin/runlab"
sed -i "s|/share/education|$HOME/organizations|g" "$HOME/bin/runlab"
chmod a+rx "$HOME/bin/runlab"
export PATH="$HOME/bin:$PATH"
hash -r
type -a runlab
```

The first result from `type -a runlab` must be `$HOME/bin/runlab`. Then run:

```bash
runlab elkdefense
```

`runlab` copies each node directory to `/tmp/<node>` on that node and executes its `install` script. It may appear to hang after finishing; press Enter once and check whether it reports completion.

If it fails, wait a few minutes and retry `runlab elkdefense` once. The scripts are intended to be idempotent. If it fails again, inspect the failing node rather than repeatedly recreating the experiment:

```bash
ssh NODE_NAME 'sudo tail -n 100 /var/log/elk-lab-install.log'
```

## 8. Run the automated validation

From the XDC:

```bash
bash "$HOME/organizations/elkdefense/validate-lab.sh"
```

This checks SSH access to all six nodes, HTTP, DNS, and gateway forwarding. Every line should report `PASS`.

## 9. Inspect node health

Run these targeted checks:

```bash
ssh gateway 'ip -brief address; ip route; /usr/sbin/sysctl net.ipv4.ip_forward; sudo /usr/sbin/iptables -S ELKLAB_FORWARD'
ssh webserver 'systemctl --no-pager --full status nginx dnsmasq ssh; ss -lntup'
ssh fileserver 'systemctl --no-pager --full status ssh vsftpd; ss -lntup'
ssh client 'systemctl --no-pager --full status elk-lab-benign.timer; ip -o -4 address | grep 172.16.10'
ssh attacker 'systemctl --no-pager --full status elk-lab-attack.timer; ip -o -4 address | grep 172.17.20'
ssh elk 'nproc; free -h; /usr/sbin/sysctl vm.max_map_count; cat /opt/elk-lab/README-FIRST.txt'
```

Expected results:

- forwarding is `1`;
- Web, DNS, SSH, and FTP services are active;
- both timers are active;
- client has 20 aliases in `172.16.10.0/24`;
- attacker has 20 aliases in `172.17.20.0/24`;
- ELK has at least four cores, approximately 16 GB RAM, and `vm.max_map_count=262144`.

## 10. Observe workloads for at least ten minutes

The benign timer starts after approximately two minutes; the attack timer starts after approximately five minutes.

```bash
ssh client 'sudo journalctl -u elk-lab-benign.service --since "15 minutes ago" --no-pager; sudo tail -n 20 /var/log/elk-lab/benign.jsonl'
ssh attacker 'sudo journalctl -u elk-lab-attack.service --since "15 minutes ago" --no-pager; sudo tail -n 20 /var/log/elk-lab/attacks.jsonl'
ssh webserver 'sudo tail -n 30 /var/log/nginx/access.log; sudo tail -n 30 /var/log/dnsmasq.log'
ssh fileserver 'sudo tail -n 30 /var/log/auth.log; sudo tail -n 30 /var/log/vsftpd.log'
```

Verify that source addresses rotate and that at least one attacker alias generates both reconnaissance and an ordinary `/` request.

## 11. Confirm traffic crosses the gateway

Open two XDC terminals. In the first:

```bash
ssh gateway 'sudo timeout 30 tcpdump -ni any "host 10.10.10.10 or host 192.168.50.20"'
```

In the second:

```bash
ssh client 'sudo systemctl start elk-lab-benign.service'
ssh attacker 'sudo systemctl start elk-lab-attack.service'
```

The gateway capture should show traffic from the rotating source pools to the service nodes. This is the key architectural check: gateway-based monitoring and mitigation are only meaningful if the intended traffic traverses it.

## 12. Record smoke-test results

Save:

- the `mrg compile` result;
- `validate-lab.sh` output;
- install-log tails from all nodes;
- interface and route output;
- timer and service status;
- representative benign/attack ground-truth lines; and
- any failure, fix, and rerun result.

Do not publish the assignment until the complete test passes twice from a clean materialization.

## 13. Stop and release resources

When testing is complete:

```bash
stopexp elkdefense
```

Confirm in the portal that the experiment no longer holds resources. Copy any evidence you need to persistent XDC/project storage before stopping; experiment-node storage is disposable.

## 14. Distinguish lab failures from facility failures

If a previously healthy experiment loses every node and `mrg show materialization ... -S` reports a facility `mariner` waiting to come online or says that an infrapod was recreated, preserve the materialization and contact SPHERE support. Do not change lab scripts to compensate for an unavailable facility host or broken XDC tunnel.

## 15. Iterate after a failure

Make fixes in the repository first, then copy the revised `sphere/` contents back to `$HOME/organizations/elkdefense/`. Keep a short change log. For topology or image changes, stop and recreate the experiment. For installation-script changes, a clean recreation is the strongest final test even if retrying `runlab` was sufficient during debugging.
