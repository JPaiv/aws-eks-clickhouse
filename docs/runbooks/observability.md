# Runbook — Observability

Centralized telemetry for the fleet ([ADR-0014](../adr/0014-centralized-observability-on-the-hub.md),
[ADR-0016](../adr/0016-observability-transport.md)): VictoriaMetrics and
VictoriaLogs run once on the hub; a Grafana Alloy DaemonSet on every spoke
ships metrics and logs to them over the shared VPC.

## Bring-up order

The spoke shipper needs the hub's ingest endpoints, and those are internal NLB
hostnames AWS only assigns once the hub Services exist — so this is a two-step,
the same late-binding as `task fleet:harden`.

### 1. The hub stores come up first

`victoria-metrics` and `victoria-logs` (in `apps/root/`) reconcile onto the hub
when Argo syncs. Confirm:

```bash
task k8s:kubeconfig                       # hub
kubectl -n observability get pods,pvc,svc
```

Both pods `Running`, both PVCs `Bound`, and two `LoadBalancer` Services with an
internal hostname under `EXTERNAL-IP`.

### 2. Wire the spokes to the hub

```bash
task obs:endpoints
```

prints each LoadBalancer Service and its NLB hostname, e.g.

```
victoria-metrics-victoria-metrics-single-server   <hash>.elb.eu-north-1.amazonaws.com
victoria-logs-victoria-logs-single-server         <hash>.elb.eu-north-1.amazonaws.com
```

Paste them into [`apps/root/spoke-alloy.yaml`](../../apps/root/spoke-alloy.yaml),
replacing `REPLACE_ME_VM_NLB` (the `prometheus.remote_write` URL) and
`REPLACE_ME_VL_NLB` (the `loki.write` URL), and commit. Argo re-renders the
`spoke-alloy` ApplicationSet and every spoke's Alloy starts shipping.

Until this commit, Alloy runs but its writes fail harmlessly against the
placeholder host — no crash, it retries once the real host lands.

## Reaching the UIs

No ingress — port-forward, like Argo CD:

```bash
task obs:metrics    # vmui  -> http://localhost:8428/vmui
task obs:logs       # VL UI -> http://localhost:9428
```

## Verify end-to-end

On the hub, after the spoke Alloy has been shipping for a minute or two.

**Metrics** — in vmui (`task obs:metrics`), run:

```promql
up{cluster="per-en1-dev-clickhouse"}          # spoke targets are being scraped
count(ClickHouseMetrics_Query{cluster="per-en1-dev-clickhouse"})   # ClickHouse itself
```

The first proves the spoke's cAdvisor/pod scraping reaches the hub; the second
proves ClickHouse's `:9363/metrics` endpoint (enabled in `clickhouse.yaml`) is
discovered via its pod annotations.

**Logs** — in the VictoriaLogs UI (`task obs:logs`), query:

```logsql
cluster:per-en1-dev-clickhouse
```

Pod logs from the spoke should stream in.

## Troubleshooting

- **`up` empty / no spoke data.** Check Alloy is healthy on the spoke:
  `task k8s:kubeconfig CLUSTER=per-en1-dev-clickhouse` then
  `kubectl -n observability get ds` and
  `kubectl -n observability logs ds/alloy -c alloy | grep -i "remote_write\|error"`.
  A `connection refused`/`no such host` means the NLB hostnames in
  `spoke-alloy.yaml` are still the placeholder or wrong — redo step 2.
- **Spoke Alloy connects nowhere (timeout).** The internal NLB isn't admitting
  spoke traffic. The in-tree cloud provider should open the hub node SG for the
  NLB NodePort scoped to `loadBalancerSourceRanges` (10.0.0.0/16); if it didn't,
  add an explicit ingress rule on the hub `cluster_security_group_id` for
  8428/9428 from the VPC (the OpenTofu fallback noted in ADR-0016).
- **cAdvisor metrics duplicated N×.** The per-node keep rule (`NODE_NAME`) isn't
  matching — check the `NODE_NAME` env is injected on the Alloy pods and equals
  `__meta_kubernetes_node_name`.
- **ClickHouse metrics missing but node metrics present.** The pod annotations
  aren't on the ClickHouse pods, or `:9363` isn't listening — check
  `kubectl -n clickhouse get pod chi-dev-default-0-0-0 -o jsonpath='{.metadata.annotations}'`
  and `kubectl -n clickhouse exec chi-dev-default-0-0-0 -c clickhouse -- wget -qO- localhost:9363/metrics | head`.
