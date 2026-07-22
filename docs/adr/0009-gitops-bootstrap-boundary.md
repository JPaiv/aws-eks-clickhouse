# ADR-0009 — OpenTofu bootstraps, ACK and Argo CD own day-2

- **Status:** Accepted — amended by [ADR-0013](0013-hub-and-spoke-fleet.md) (single-cluster assumption: spokes are now ACK-managed from Git)
- **Date:** 2026-07-22

## Context

The stack needs AWS resources that are not the cluster: an S3 bucket for
ClickHouse storage disks, IAM roles for the service accounts that reach it, KMS
keys, possibly more as the cluster grows. There are two places those can be
managed from — OpenTofu, or ACK controllers running inside the cluster — and
picking one per-resource ad hoc is how infrastructure repositories become
unexplainable.

Managing everything in OpenTofu means day-2 changes need a pipeline holding
long-lived AWS credentials with broad permissions, and drift is only discovered
the next time someone runs `plan`. Managing everything in ACK is impossible:
the controllers run in the cluster, so nothing the cluster needs in order to
exist can be managed by them.

The constraint is therefore not a preference. It is a bootstrap ordering
problem, and the boundary has to fall where the circular dependency does.

## Decision

**OpenTofu, orchestrated by Terramate, is scaffold and bootstrap only. Once the
cluster can run Argo CD, Git becomes the source of truth and ACK owns the
remaining AWS resources.**

The rule that decides ownership, in one sentence:

> If the cluster must have it in order to start reconciling, OpenTofu owns it.
> Everything else is a Kubernetes manifest in Git.

Concretely, OpenTofu/Terramate owns:

- Remote state backend (S3 with native `use_lockfile` locking)
- Network — VPC, subnets, endpoints
- The EKS control plane and a bootstrap node group
- OIDC provider and the IAM roles for the ACK controllers and Argo CD, via
  EKS Pod Identity
- The Argo CD install itself, and the single root `Application` that points at
  this repository

Everything after that root Application is GitOps: Argo CD reconciles manifests
from Git, ACK controllers turn `s3.services.k8s.aws/Bucket` and
`iam.services.k8s.aws/Role` resources into real AWS resources, and the
ClickHouse operator and installations arrive the same way.

The bootstrap surface is deliberately small and deliberately boring. It should
change a handful of times a year; the interesting change rate lives in Git.

## Consequences

- One reconciliation loop for day-2. Drift is corrected continuously instead of
  at the next `plan`, and the correction is visible in the Argo CD UI rather
  than in a CI log nobody reads.
- The AWS resources ClickHouse depends on ship in the same Application as
  ClickHouse itself. One sync, one diff, one rollback — instead of "apply the
  bucket in OpenTofu, then sync the workload" as two operations that can be
  half-done.
- No long-lived AWS admin credentials in CI for ongoing work. Only the bootstrap
  needs them, and the bootstrap is run by a human.
- **Two systems own AWS resources, and the boundary will rot if it is not
  enforced.** The one-sentence rule above is the enforcement; anything that
  needs an exception needs an ADR superseding this one. The predictable failure
  is a resource added to OpenTofu because it was quicker that afternoon.
- **`tofu plan` stops showing the whole picture.** State is split three ways —
  OpenTofu state, cluster etcd, and AWS reality. Diagnosing "what does AWS
  actually look like" now means checking two systems.
- **Teardown gets sharper edges.** `task destroy` knows nothing about
  ACK-managed resources. With ACK's default `deletionPolicy: delete`, deleting
  the cluster can take an S3 bucket holding ClickHouse data with it; with
  `retain`, it silently leaves resources billing. Deletion policy is a decision
  per resource, not a default to inherit, and teardown becomes: drain the
  Applications first, then run `task destroy`.
- ACK controller coverage across AWS services is uneven. Where a controller is
  missing or immature, the fallback is OpenTofu — which reintroduces the
  boundary question for that resource, and should be recorded when it happens.
- Rebuilding from nothing is now two phases: `task apply` for the bootstrap,
  then wait for Argo to converge. That is slower to describe but easier to
  trust, because the second phase is reproducible from Git alone.
- This narrows the scope of [ADR-0002](0002-terramate-over-terragrunt.md)
  without superseding it. Terramate still decomposes and orchestrates the
  bootstrap stacks; there are simply fewer of them than a
  manage-everything-in-OpenTofu design would have.

## Alternatives considered

- **Everything in OpenTofu, no ACK, no GitOps.** The simplest mental model and a
  single source of truth. Rejected because day-2 then requires a pipeline with
  standing AWS admin credentials, and because drift detection degrades to
  "whenever someone remembers to plan". For a stack whose whole point is showing
  a production-shaped operational model, that is the wrong trade.
- **Everything in ACK, including the EKS cluster.** Moves the chicken-and-egg
  problem rather than solving it — you need a management cluster to run the
  controllers that create the cluster. Correct at fleet scale, absurd for one.
- **Crossplane instead of ACK.** More capable: composition, provider
  abstraction, claims. Rejected because it is a large concept surface to
  introduce alongside Terramate and Argo, and because ACK maps one-to-one onto
  AWS APIs — when something breaks, the AWS documentation is the documentation.
  Worth revisiting if the stack ever spans providers.
- **Flux instead of Argo CD.** A genuinely close call; Flux's Kustomize-native
  model is arguably tidier. Argo CD wins on the diff and sync UI, which makes
  the reconciliation loop legible to someone reading this repository rather than
  operating it.
- **Terraform Controller / tofu-controller in-cluster.** Keeps a single IaC
  language while getting the reconciliation loop. Rejected as a third
  orchestration layer on top of Terramate and Argo, with a smaller community
  than either.
