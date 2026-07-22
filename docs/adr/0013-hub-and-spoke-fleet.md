# ADR-0013 — Hub-and-spoke fleet: spoke clusters are Git manifests

- **Status:** Accepted — amends [ADR-0009](0009-gitops-bootstrap-boundary.md) and [ADR-0012](0012-ack-identity-fixed-point.md)
- **Date:** 2026-07-22

## Context

One cluster running both the management plane and ClickHouse conflates two
lifecycles: upgrading the data plane risks the thing that manages it, and a
second environment means hand-building a second everything. The direction is
a fleet treated as cattle — worker clusters that are disposable, reproducible
from Git, and never individually cared for.

ADR-0009 assumed a single cluster; ADR-0012 scoped the ACK EKS controller to
Pod Identity associations "on this one cluster". Both assumptions fall here.

## Decision

**The admin cluster is the hub; worker EKS clusters are spokes created and
managed entirely from Git by the hub's ACK EKS controller.** A spoke is a
directory under `apps/spokes/` — copy it to add one, delete it to retire one.

The load-bearing choices:

- **Spokes are EKS Auto Mode clusters.** Karpenter, CNI, EBS CSI, load
  balancing and Pod Identity are control-plane managed, so a spoke needs
  zero in-cluster bootstrap — one Cluster manifest is the whole cluster.
  Cost: a management fee (~10% on EC2), accepted as the price of cattle.
- **Spokes share the hub VPC's** private subnets. No per-spoke networking,
  no peering, one NAT bill.
- **Per-spoke IAM roles from a list.** `stacks/admin/fleet` generates
  `<cluster-name>-cluster` / `<cluster-name>-node` for each entry in
  `local.spokes`. Adding a spoke is one list entry plus its manifests. These
  roles are deliberately outside the `/ack/` boundary: they are
  infrastructure roles assumed by AWS services, and the boundary (no
  `ecr:*`, no `eks:*`) would break nodes. The boundary stays reserved for
  workload roles born in Git.
- **One tagging convention for the whole estate:** every cluster-affiliated
  resource — TF-made or ACK-made — carries a `Cluster` tag naming the EKS
  cluster it belongs to. The EKS controller's `CreateCluster` permission is
  conditioned on that tag, so an untagged spoke cannot exist.
- **The hub is protected by an explicit Deny** on
  `eks:DeleteCluster`/`UpdateClusterConfig`/`UpdateClusterVersion` for the
  hub ARN — Git can create Pod Identity associations on the hub (the fixed
  point) but can never break the hub itself.
- **Argo CD deploys into spokes with one credential-less role.**
  `per-en1-admin-ack-argocd` is bound by Pod Identity to the
  application-controller, applicationset-controller and server; it has no
  IAM permissions — spoke authorization is a per-spoke `AccessEntry`
  manifest granting `AmazonEKSClusterAdminPolicy`. The cluster Secret omits
  `roleARN`, so Argo uses its ambient credentials.
- **Late-bound registration via ACK FieldExport.** The cluster Secret is
  committed with an empty `server`; a FieldExport patches the spoke's
  endpoint in once the cluster is ACTIVE. The spokes Application ignores
  that one key (`ignoreDifferences` + `RespectIgnoreDifferences`), so
  selfHeal does not fight the controller.
- **Workloads target spokes by label, not name:** the `spoke-baseline`
  ApplicationSet matches cluster Secrets labelled `fleet: spoke` and lands
  the baseline on every one — the mechanism that makes spokes
  interchangeable.

## Consequences

- Cluster count stops being an OpenTofu concern. TF's per-spoke surface is
  one line in a list; everything else — cluster, access, registration,
  workloads — is Git.
- The ADR-0012 tension is resolved: account-id-bearing ARNs and subnet IDs
  are **committed as literals** in `apps/spokes/`. Account ids are not
  secrets (AWS's own guidance); the state bucket stays env-injected only
  because backend blocks cannot interpolate.
- The spoke registration is born with `tlsClientConfig.insecure: true` —
  the CA is unknowable before the cluster exists, and FieldExport can only
  write scalar keys, not compose the `config` JSON. Hardening is one commit
  (`task fleet:harden` prints the `caData`). The window is
  IAM-authenticated traffic to a private-network endpoint; accepted,
  documented, and closed per spoke after bring-up.
- FieldExport is deprecated upstream in favour of kro. The version pin
  contains the risk; adopting kro (CEL-composed secrets, no insecure birth)
  is the designated successor if FieldExport disappears — revisit then
  rather than adding a third orchestration concept now.
- The scoped controller policy can lag ACK releases (same trade as
  ADR-0012, larger surface): a controller version that starts calling a new
  EKS API fails until the policy is widened in TF.
- Argo CD pods must be restarted once after the identity apply to pick up
  their Pod Identity credentials — a runbook step, not automation.

## Alternatives considered

- **Self-hosted Karpenter per spoke.** No management fee and full version
  control, but each spoke then needs a bootstrap node group, controller
  role, interruption queue and chart pins before its first real node — 
  per-head ceremony is exactly what cattle forbids.
- **Managed node groups per spoke.** Simpler than self-hosted Karpenter,
  still per-spoke capacity manifests to right-size forever; Auto Mode's
  NodePools do that dynamically.
- **Per-spoke VPCs (ACK ec2-controller or TF).** Stronger isolation, at the
  cost of per-spoke NAT, peering/TGW for hub reachability, and either a new
  controller or per-spoke TF churn. Shared VPC wins until isolation is a
  requirement.
- **kro instead of FieldExport** for the registration secret. Composes the
  whole secret (no insecure birth), but introduces a third orchestration
  layer next to Terramate and Argo — the same reasoning that rejected
  Crossplane in ADR-0009.
- **Shared fleet-wide role pair** (AWS's own Auto Mode suggestion). Zero TF
  churn per spoke, but role names cannot say which cluster they serve and
  audit trails blur — rejected for `<cluster-name>-<role-name>` clarity.
