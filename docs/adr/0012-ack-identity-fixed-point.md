# ADR-0012 — OpenTofu's identity fixed point: the ACK iam and eks controllers

- **Status:** Accepted
- **Date:** 2026-07-22

## Context

ADR-0009 draws the boundary: after bootstrap, ACK controllers own AWS
resources from inside the cluster. But every ACK controller needs two things
before its first reconcile: an IAM role, and an EKS Pod Identity association
binding that role to its service account. Roles could come from the ACK IAM
controller — except the *associations* are an EKS API call the IAM controller
cannot make. Bootstrapping only the IAM controller therefore leaks identity
work back into OpenTofu on every future controller, which is exactly the
drift ADR-0009 warns about.

There is also a power problem: a controller that can create arbitrary IAM
roles is a privilege-escalation machine unless something bounds what the
roles it creates can do.

## Decision

**OpenTofu bootstraps Pod Identity for exactly two ACK controllers — iam and
eks — plus one permissions boundary, and then never touches identity again.**

The fixed point: the IAM controller creates roles from Git
(`iam.services.k8s.aws/Role`), the EKS controller creates associations from
Git (`eks.services.k8s.aws/PodIdentityAssociation`). Every future controller
(s3, kms, …) onboards purely as manifests under `apps/`.

Guardrails, enforced by the controller policies in `stacks/admin/identity`:

- ACK-created roles and policies live under the IAM path **`/ack/`** —
  scoping is by resource ARN (`role/ack/*`), so nothing outside the path is
  reachable at all.
- `iam:CreateRole` and `iam:PutRolePermissionsBoundary` carry an
  `iam:PermissionsBoundary` condition: a role without the OpenTofu-owned
  boundary is denied at creation. `iam:DeleteRolePermissionsBoundary` is
  never granted, so the boundary cannot be stripped afterwards.
- The boundary itself contains **no `iam:*` actions** — an ACK-created role
  can never mint identity, whatever policies get attached to it.
- The controller roles sit at the default path `/`, not `/ack/`, so the IAM
  controller cannot rewrite its own permissions.

## Consequences

- Onboarding a new ACK controller is a pull request: one Application
  manifest, one Role manifest, one PodIdentityAssociation manifest. No
  OpenTofu, no AWS credentials, no human at a terminal.
- The boundary is the blast-radius ceiling for everything born in Git. It
  starts narrow (label-prefixed S3, KMS data-plane, logs, EC2 reads) and
  **widening it is a deliberate, reviewed OpenTofu change** — expected when
  the ClickHouse applications land.
- Role manifests in Git must reference the boundary ARN, which embeds the
  account id — the same public-repo tension ADR-0010 avoids for the state
  bucket. To be resolved when the first ACK Role manifest lands (options:
  ArgoCD config-management plugin, a committed id, or Kustomize overlay);
  deferred deliberately.
- The two controller charts are pulled anonymously from `public.ecr.aws`
  (1 pull/s, 500 GB/month unauthenticated) — trivially sufficient for two
  charts refreshed by one repo-server.
- Scoped-down policies can lag ACK controller releases: if a new controller
  version starts calling an API the narrowed policy lacks, reconciliation
  fails until the policy is updated in OpenTofu. The recommended upstream
  policies would avoid that at the cost of `Resource: "*"`.

## Alternatives considered

- **Bootstrap only the IAM controller.** Smaller fixed point, but every
  future controller needs an OpenTofu change for its association — the
  gitops goal erodes one controller at a time.
- **IRSA instead of Pod Identity.** Works, but needs the OIDC provider
  wired per role and stitches trust policies to service accounts by string;
  Pod Identity is the successor AWS points to, and the association is a
  first-class ACK resource, which is what makes the fixed point closable.
- **No boundary, recommended upstream policies.** Simplest and always
  API-compatible, but hands cluster workloads a role factory with
  `Resource: "*"`. Wrong default even for a demo account.
- **cluster-wide admin role for one "platform" controller set.** Fewer
  moving parts, no per-service scoping — rejected for the same reason.
