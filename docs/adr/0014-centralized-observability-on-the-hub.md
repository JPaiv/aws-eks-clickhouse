# ADR-0014 — Centralized observability: the hub watches, the spokes ship

- **Status:** Accepted
- **Date:** 2026-07-23

## Context

The data plane needs metrics, logs and dashboards (README roadmap). The fleet
is hub-and-spoke ([ADR-0013](0013-hub-and-spoke-fleet.md)): spokes are cattle,
created and retired by deleting a directory. A monitoring stack replicated
into every spoke fights that directly — it makes each spoke stateful, adds a
per-spoke resource floor before any workload runs, and scatters the operator's
attention across N UIs. Whatever observes the fleet has to outlive any member
of it.

## Decision

**Telemetry storage and UIs run once, on the hub. Spokes run only a shipper.**

- **Grafana Alloy** is the single collector, a DaemonSet in
  `apps/fleet/baseline` — so every `fleet: spoke` cluster ships metrics and
  logs from the moment the ApplicationSet lands, zero per-spoke wiring. One
  agent for both signals; no promtail-plus-exporter zoo.
- **VictoriaMetrics** (single-node) receives `remote_write` on the hub;
  **VictoriaLogs** receives logs. Both chosen for the same reason Auto Mode
  spokes were: minimal operational surface per unit of capability — one
  binary each, PVs on hub EBS, resource needs that fit a portfolio budget.
- **UIs live on the hub only** (vmui/VL UI first, Grafana when dashboards
  earn it), reached the same way as Argo CD: port-forward, no public
  ingress.
- Spokes keep **no telemetry state**. Deleting a spoke directory deletes
  nothing observability-related except the shipper that ran there; history
  stays on the hub.
- Transport rides the shared VPC ([ADR-0013](0013-hub-and-spoke-fleet.md)):
  spoke Alloy reaches the hub's in-VPC endpoints privately. No cross-VPC,
  no public exposure of ingest.

## Consequences

- One pane of glass, and new spokes are observed by construction — the same
  label-selector mechanism that lands workloads lands the shipper.
- The hub grows its first stateful workloads (VM and VL PVs). That is
  consistent with its pet lifecycle, but backup/retention policy for
  telemetry now needs an answer on the hub, not per spoke.
- A hub outage is a fleet-wide telemetry gap. Alloy buffers briefly, not
  indefinitely; accepted — the hub is already the fleet's single point of
  management, and the monitoring of last resort is CloudWatch's control
  plane metrics, which never left.
- Ingest endpoints are unauthenticated inside the VPC to start. The VPC
  boundary is the auth boundary, same posture as the spoke registration
  window in ADR-0013 — and hardening (tenant tokens, TLS) is additive
  later.
- The multi-account future ([ADR-0013](0013-hub-and-spoke-fleet.md),
  deferred section) breaks the flat-network assumption: cross-account
  shipping needs PrivateLink or authenticated public ingest. Deliberately
  unsolved until that ADR is written.
- Cardinality is a hub-capacity problem now: a misbehaving spoke can flood
  the shared store. Alloy-side relabel/drop rules are the throttle, applied
  in the baseline so they apply fleet-wide.

## Alternatives considered

- **kube-prometheus-stack per spoke.** The default answer, and the wrong
  shape here: Prometheus + Grafana + Alertmanager per spoke is a stateful
  floor under every cattle cluster and N places to look. Federation to fix
  the N-places problem re-invents the central store with more moving parts.
- **Thanos or Mimir + Loki, centralized.** The same topology with
  heavier-duty storage: object-store-backed, horizontally scalable,
  multi-tenant. The right call at real fleet scale; at this one, three to
  five more deployments per signal for capacity nothing here needs.
- **Managed (AMP/CloudWatch, or Grafana Cloud).** Least to operate and the
  strongest answer to "the hub is down" — but this stack exists to
  demonstrate operating things, per-metric pricing punishes ClickHouse's
  natural cardinality, and the GitOps story degrades to configuring an
  external SaaS from manifests.
- **VictoriaMetrics on the spoke it observes.** Keeps telemetry next to the
  workload, dies with the spoke — which is exactly the property cattle
  forbid: the post-mortem needs the telemetry of the thing that died.
