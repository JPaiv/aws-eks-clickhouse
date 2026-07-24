# ADR-0015 — ClickHouse data plane: S3-backed storage, Pod Identity, per-spoke workloads

- **Status:** Accepted
- **Date:** 2026-07-24

## Context

The bootstrap, fleet and ACK controllers are done; the roadmap's next item is
the ClickHouse cluster itself — sharding, replication, S3-backed storage. The
Keeper quorum and the Altinity operator already land on every spoke
([ADR-0013](0013-hub-and-spoke-fleet.md)); what remains is the
`ClickHouseInstallation` and the AWS resources it needs.

Two problems have to be solved to get there, and neither is covered by the
existing patterns:

1. **Nothing delivers a *per-spoke* workload to a spoke.** Everything under
   `apps/spokes/` is applied to the **hub** (the `spokes` Application targets
   `kubernetes.default.svc` recursively) — those are ACK CRs the hub's
   controllers reconcile. The only things that run *on* a spoke come from the
   `spoke-baseline` and `spoke-clickhouse-operator` ApplicationSets, both
   pointed at the **generic** `apps/fleet/baseline`. But a ClickHouse cluster
   references its own S3 bucket — it is not generic.

2. **ClickHouse needs AWS credentials for S3, without static keys.** The
   fleet standard is EKS Pod Identity ([ADR-0013](0013-hub-and-spoke-fleet.md)),
   and the ACK identity fixed point ([ADR-0012](0012-ack-identity-fixed-point.md))
   already lets a workload role onboard from Git.

## Decision

**ClickHouse stores table data in S3, authenticates with EKS Pod Identity, and
is delivered to its spoke by a new per-spoke workload tier. No OpenTofu
change.**

The load-bearing choices:

- **A per-spoke workload tier.** A third ApplicationSet, `spoke-clickhouse`,
  uses the same `fleet: spoke` cluster generator as the baseline, but its
  `source.path` is templated: `apps/fleet/{{.name}}`. The template's own
  fields are rendered (unlike manifests inside a plain directory source), so
  each spoke pulls its own directory. Convention: **`apps/fleet/baseline` =
  every spoke; `apps/fleet/<cluster-name>` = that one spoke.** This keeps the
  cattle model (label-selected, no per-spoke Application wiring) while letting
  spokes legitimately differ, and adds no Helm chart or new templating concept.

- **S3-primary storage, expressed as operator `settings`, not XML.** The
  `storage_configuration` is written as slash-path keys under
  `spec.configuration.settings` (which the operator renders into `config.d`
  XML) rather than a raw XML blob in `spec.configuration.files` — native YAML,
  line-diffable, consistent with the rest of the repo. An `s3` disk holds the
  data; a `cache` disk in front of it keeps metadata-heavy operations fast; a
  small local gp3 PVC holds that cache and the S3 metadata (not table data).
  `s3_main` is the default MergeTree policy, so every table lands on S3.

- **Credentials via Pod Identity, `use_environment_credentials`.** The
  ClickHouse pods run as a dedicated `clickhouse` ServiceAccount bound by a
  `PodIdentityAssociation` to a workload role born in Git
  (`per-en1-dev-clickhouse-s3`, path `/ack/`, the OpenTofu boundary, scoped to
  the one bucket). ClickHouse reads the injected `AWS_CONTAINER_*` env — no
  keys in config. This requires **ClickHouse ≥ 24.11** (EKS Pod Identity uses
  a token *file*, only read since #71269); the 26.3.x pin, matched to the
  Keeper image, clears it.

- **1 shard × 2 replicas.** Replicated and HA across two AZs — the cheapest
  layout that still exercises replication. `minDomains: 2` forces the spread,
  the same trick the Keeper uses. Sharding is a one-line `layout` change when
  a workload needs it.

- **The bucket is an ACK resource, hub-side.** The `s3.services.k8s.aws/Bucket`,
  the role and the association live in `apps/spokes/dev-clickhouse/` with the
  spoke's other ACK CRs — created by the S3, IAM and EKS controllers on the
  hub. Only the ServiceAccount and the CHI run on the spoke.

## Consequences

- **First real node spend on the fleet.** Two ClickHouse pods wake Auto Mode
  nodes on the spoke — until now spokes were empty control planes. S3-primary
  keeps EBS tiny (one 20Gi gp3 PVC per pod; table data is in S3).
- **A first-sync dance, by design.** Bucket → role → association → pods each
  depend on the prior and reconcile asynchronously; pods may crashloop until
  the association is ACTIVE, then recover — the same eventual convergence the
  operator/baseline already rely on, and the same one-restart caveat as
  ADR-0013's Argo note.
- **Still zero OpenTofu.** The boundary already permits `s3:*` on `per-en1-*`
  and `PassRole` on `role/ack/*`; the EKS controller already creates
  associations on `cluster/per-en1-*`. ClickHouse's identity is pure Git — the
  ADR-0012 fixed point, used a second time.
- **The S3 bucket name is global.** `per-en1-dev-clickhouse-data` carries the
  boundary's prefix but is not guaranteed unique; a collision fails
  CreateBucket and is fixed by appending a suffix.
- **Scoped policy can lag ClickHouse.** If a future ClickHouse feature calls an
  S3 action the role's inline policy lacks, it fails until the manifest is
  widened — the same trade as the controller policies (ADR-0012).

## Alternatives considered

- **Storage config as raw XML in `files`.** The common Altinity recipe, and
  unambiguous, but an XML document escaped inside YAML: fragile indentation, no
  line-diffs, unlike anything else in this repo. Settings slash-keys render to
  the same XML.
- **Put the CHI in the generic baseline.** Zero new machinery, but the baseline
  is identical on every spoke — it cannot name a per-spoke bucket without
  becoming a templated Helm chart, a heavier concept than a per-spoke directory.
- **IRSA instead of Pod Identity.** Works on older ClickHouse (no token-file
  floor), but the fleet is standardized on Pod Identity (ADR-0013) and the
  association is a first-class ACK resource — consistency wins.
- **Tiered hot→cold storage** (recent data on EBS, aged data to S3 by TTL).
  More production-realistic, but more EBS and a more complex policy than a dev
  cluster proving out the S3 path needs; revisit per workload.
- **Zero-copy replication** (replicas sharing S3 objects). Halves storage, but
  has known correctness caveats and is discouraged for production — each
  replica keeps its own copy instead.
