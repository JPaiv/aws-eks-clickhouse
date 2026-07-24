# ADR-0017 — Git as the source of truth: one provider now, multi-provider at prod scale

- **Status:** Accepted
- **Date:** 2026-07-24

## Context

Argo CD reconciles the entire fleet from a single GitHub repository
([ADR-0009](0009-gitops-bootstrap-boundary.md)): the ACK controllers, the
spokes, every workload, and the observability stack all originate there. GitHub
is therefore a hard dependency of the **change-delivery path**.

A GitHub outage on 2026-07-24 made the exposure concrete, and also its shape.
What broke was narrow — the pull-request / GraphQL subsystem, so a merge could
not be made through the normal flow — and it was worked around with a direct
`git push`, which was never affected. Crucially, what did **not** break:

- **The running fleet.** Kubernetes enforces last-applied state with no GitHub
  dependency, and Argo CD keeps enforcing its last-reconciled manifests from the
  repo-server cache, `selfHeal` included. **A GitHub outage is not a data-plane
  outage.**
- **The image path.** ACK charts and ClickHouse images come from
  `public.ecr.aws`, Docker Hub and Altinity — not GitHub.

So the real risk is not availability; it is the **inability to ship a change
during an outage** — worst when a coincident incident needs a rollback or
hotfix and the GitOps path is the only sanctioned way to make one. Two smaller
edges compound it: new spoke/ACK provisioning is blocked while Git is
unreachable, and two Helm sources — `grafana.github.io` and
`victoriametrics.github.io` — are GitHub Pages, so a *fresh* sync of Alloy / VM
/ VL could stall even though running pods are cached.

## Decision

**For this single-account sandbox, accept GitHub as the sole Git provider. Put
on record that multi-provider Git is a production requirement, not an
optimization — deferred until the trigger below.**

- The exposure here is change-delivery latency, not fleet availability, so the
  proportionate mitigation is **break-glass discipline, not redundancy**: when
  it earns the effort, a runbook to pause an app's `selfHeal`, apply an
  emergency `kubectl` change, and reconcile back once GitHub returns.
- **At production scale, a Git mirror Argo can fail over to becomes a
  requirement.** The trigger is the same one ADR-0013 and ADR-0014 name for
  their deferred halves: when this stack carries real production, or gains a
  second account, or takes on an SLA on change delivery. At that point the
  source of truth cannot have a single vendor as its single point of failure.
- The GitHub-Pages **chart-path** edge closes far more cheaply than the repo
  itself — vendoring those two charts into the ECR OCI mirror removes GitHub
  from the chart path entirely — and is the first increment when hardening
  starts, ahead of full repo redundancy.

## Consequences

- The fleet survives GitHub outages as-is; only new changes and new
  provisioning block. That is an acceptable posture for a sandbox and an
  unacceptable one for prod — which is the whole point of recording it now.
- Until a mirror exists, MTTR during a coincident incident rests on break-glass,
  which today is undocumented. Writing that runbook is the cheapest first step
  and does not wait for the multi-provider work.
- The multi-account future ([ADR-0013](0013-hub-and-spoke-fleet.md), deferred
  section) is the natural moment to implement the mirror: per-account bootstrap
  is already being reworked there, and a provider-independent source of truth
  rides along with it.
- Committing to a mirror later constrains nothing now — the GitOps model is
  provider-agnostic already (Argo takes any Git URL); only the `repoURL` values
  and a sync-mirror change hands.

## Alternatives considered

- **Multi-provider Git now.** The correct end state, but ceremony this scale
  does not need: a mirror to keep in sync, failover to rehearse, and `repoURL`
  indirection to maintain, for a sandbox whose worst case today is a delayed
  merge. Premature.
- **Self-hosted Git as the primary.** Removes the GitHub dependency outright,
  but trades it for operating a Git service, and forfeits the collaboration and
  CI that make GitHub the primary in the first place. Wrong default.
- **Accept and do nothing, permanently.** Fine for the sandbox, but leaves prod
  with no answer and no break-glass — rejected as the *eventual* posture, which
  is exactly why this ADR fixes the direction while deferring the build.
