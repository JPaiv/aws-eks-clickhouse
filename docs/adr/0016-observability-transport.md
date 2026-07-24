# ADR-0016 — Observability transport: spokes reach the hub over an internal NLB

- **Status:** Accepted
- **Date:** 2026-07-24

## Context

[ADR-0014](0014-centralized-observability-on-the-hub.md) put the telemetry
stores on the hub and a shipper on every spoke, and said transport "rides the
shared VPC ... spoke Alloy reaches the hub's in-VPC endpoints privately." It did
not say *how* a pod on one cluster reaches a service on another. That is the gap
this ADR closes.

The constraints are concrete. Spokes and the hub are separate EKS clusters
sharing the hub VPC's private subnets ([ADR-0013](0013-hub-and-spoke-fleet.md)),
both on the VPC CNI, so every pod has a routable VPC IP — L3 reachability
exists. But a Service `ClusterIP` is not resolvable or routable across clusters,
and pod IPs are ephemeral. Something stable and cross-cluster has to front the
hub's VictoriaMetrics (`:8428`) and VictoriaLogs (`:9428`) ingest. The hub is
standard EKS 1.34 with **no AWS Load Balancer Controller**; its private subnets
already carry `kubernetes.io/role/internal-elb=1`.

## Decision

**Each hub store is fronted by an internal NLB, provisioned by the in-tree
cloud provider from a `type: LoadBalancer` Service, source-scoped to the VPC.
Alloy targets those NLB hostnames, committed into Git after the hub apply.**

- **Internal NLB via the in-tree provider.** No LB controller is installed, but
  EKS 1.34 still runs the in-tree AWS cloud-controller-manager, which reconciles
  `type: LoadBalancer` using the legacy annotations
  (`aws-load-balancer-type: nlb`, `aws-load-balancer-internal: "true"`) and the
  `internal-elb` subnet tag. It also opens the hub node SG for the NLB NodePort,
  so **no OpenTofu change** is needed. `loadBalancerSourceRanges: [10.0.0.0/16]`
  pins ingest to the shared VPC — the VPC boundary is the auth boundary, exactly
  ADR-0014's stated starting posture.
- **Two NLBs, one per store.** A Service maps to one backend, and VM and VL are
  separate binaries on different ports. Two internal NLBs (~$16/mo each) is the
  simplest shape and matches ADR-0014's "one binary each"; a single NLB behind a
  vmauth proxy is the cost optimization held for later.
- **Endpoints are committed, late-bound.** AWS assigns the NLB hostname only
  once the Service exists, so `apps/root/spoke-alloy.yaml` ships with a
  placeholder that is replaced with the real hostname after the hub apply
  (`task obs:endpoints`) — the same late-binding as the spoke CA in
  `task fleet:harden`. The value is committable: it is one hub for the whole
  fleet, and hostnames are not secrets.

## Consequences

- Spoke onboarding stays label-only: the `spoke-alloy` ApplicationSet lands the
  shipper on every `fleet: spoke` cluster, and it ships to the same two
  hostnames. New spokes are observed by construction.
- Ingest is unauthenticated plain HTTP inside the VPC. Acceptable to start
  (ADR-0014); hardening — tenant tokens, TLS — is additive and does not change
  the topology.
- The committed hostname is brittle to Service re-creation: delete and recreate
  a hub store and its NLB hostname changes, needing a re-commit. A private
  Route53 alias (a stable name in front of the NLB) removes this and is the
  designated hardening if churn becomes annoying.
- The multi-account future breaks the flat-network assumption this rides on
  (ADR-0013's deferred section): cross-account shipping needs PrivateLink or
  authenticated public ingest. Deliberately unsolved until that ADR is written.
- The in-tree provider is deprecated upstream. It is present and supported on
  EKS 1.34; if a future EKS release drops it, the successor is the AWS Load
  Balancer Controller (IP-target NLBs), installed as its own Git-onboarded
  controller — a larger change, revisited then.

## Alternatives considered

- **AWS Load Balancer Controller + IP-target NLB.** The modern path (pods as
  targets, no NodePort hop), but it means installing and maintaining another
  controller for two Services the in-tree provider already handles. Adopt it
  when something else needs it.
- **A private Route53 hosted zone with fixed names.** Removes the committed-
  hostname brittleness, but adds a hosted zone + records (OpenTofu or the ACK
  route53 controller) for a problem that is one re-commit today. Deferred as
  hardening, not baseline.
- **NodePort + a committed hub node IP.** Zero LB cost, but not HA and breaks
  when the node is replaced — the opposite of what a fleet's monitoring should
  be.
- **Expose ingest publicly (public NLB + auth).** Needed only in the multi-
  account world; inside one flat VPC it trades the VPC auth boundary for tokens
  and TLS with nothing gained.
