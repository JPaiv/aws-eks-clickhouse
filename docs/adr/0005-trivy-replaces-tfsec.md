# ADR-0005 — Trivy replaces tfsec

- **Status:** Accepted
- **Date:** 2026-07-22

## Context

The dev container shipped `tfsec` for IaC misconfiguration scanning, with a
comment in the Dockerfile already noting that tfsec is in maintenance mode.

Aqua Security, tfsec's maintainer, folded its rule engine into Trivy. tfsec
still runs, but its checks are no longer where new rules land, and its last
release predates a good deal of current AWS surface area.

This repo also needs scanning that tfsec never covered: it deploys Kubernetes
workloads (the ClickHouse operator, Keeper, ACK controllers) from Helm charts
and manifests, and pulls container images.

## Decision

Trivy replaces tfsec. `task sec` runs:

```bash
trivy config --exit-code 1 --misconfig-scanners terraform .
```

The VS Code extension changes from `tfsec.tfsec` to
`AquaSecurityOfficial.trivy-vulnerability-scanner`.

The scanner is scoped to `terraform` for now because that is all the repo
contains. As Kubernetes manifests and Helm charts land, the scanner list widens
rather than a second tool being introduced — the same binary already handles
`kubernetes`, `helm`, `dockerfile` and image scanning.

## Consequences

- The misconfiguration rules stay current, since this is where Aqua ships them.
- One tool covers IaC, Kubernetes manifests, Helm charts, Dockerfiles and
  container images — a single scanner to pin, configure and read output from.
- Rule IDs change from `AWS###` (tfsec) to `AVD-AWS-####` (Trivy). Any inline
  ignore comments would need translating; there are none yet, which is the
  cheapest possible moment to switch.
- Trivy downloads and caches its rule database on first run, so the first
  `task sec` in a fresh container is slower and needs network access.
- Trivy's default severity handling is broader than tfsec's. Expect an initial
  round of triage when real infrastructure code lands, and expect to add a
  `trivy.yaml` with explicit ignores at that point.

## Alternatives considered

- **Stay on tfsec.** Zero migration cost today, guaranteed rot tomorrow, and it
  would still leave Kubernetes and image scanning uncovered.
- **Checkov.** Comparable coverage and good Kubernetes support, but a Python
  install rather than a single static binary, which is a meaningfully heavier
  thing to pin in a container image.
- **Both Trivy and tfsec.** Overlapping findings with different IDs, double the
  triage, no additional coverage.
