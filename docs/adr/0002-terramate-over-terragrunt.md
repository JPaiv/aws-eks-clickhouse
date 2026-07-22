# ADR-0002 — Terramate replaces Terragrunt

- **Status:** Accepted
- **Date:** 2026-07-22

## Context

The stack is split into multiple units — network, EKS cluster, node groups, the
ClickHouse operator, the ClickHouse installation itself — because keeping them
in one state file makes every change a whole-cluster risk. Splitting them
creates the problems every multi-state Terraform repo has: orchestrating runs in
dependency order, keeping backend and provider blocks consistent across dozens
of directories, and running only what actually changed.

The dev container previously shipped Terragrunt for this. Keeping both
Terragrunt and Terramate would mean two overlapping orchestration layers.

## Decision

Terramate is the orchestration and code-generation layer. Terragrunt is removed
from the image.

The two things this buys:

- **Code generation instead of a wrapper DSL.** Terramate generates plain
  `.tf`/`.tofu` files that are committed to the repo. What runs is what you can
  read, and it can be run with bare `tofu` if Terramate is ever unavailable.
- **Change detection.** `terramate run --changed` limits a run to stacks whose
  code actually changed relative to the base branch — the mechanism that keeps
  CI on a multi-stack repo from planning everything on every push.

Terramate also stays out of the execution path: `terramate run -- tofu plan`
invokes the real binary rather than proxying it.

## Consequences

- Generated files are committed, so reviewers see the full effective
  configuration in the diff. The cost is that `task tm:generate` must be re-run
  after editing any `.tm.hcl`, and CI must fail when the working tree is dirty
  after generation.
- Backend and provider configuration is defined once and generated everywhere,
  removing the most common copy-paste drift.
- Terramate is a smaller ecosystem than Terragrunt. Fewer StackOverflow answers,
  and a real dependency on one vendor's roadmap.
- Stack dependency ordering relies on Terramate's ordering (`after`/`before`)
  rather than Terragrunt's `dependency` blocks; outputs are not wired between
  stacks implicitly. Cross-stack values go through remote state data sources or
  well-known resource names, which is more explicit and more verbose.

## Alternatives considered

- **Terragrunt.** Mature, widely understood, and the `dependency` block is a
  genuinely nicer ergonomic than remote-state lookups. Rejected because its
  wrapper DSL means the effective configuration is never directly readable in
  the repo, and because it duplicates what Terramate does here.
- **Neither — one state file per environment.** Simplest possible setup, and
  wrong for a cluster: a node-group change should not be able to touch VPC
  state.
- **Neither — plain directories plus shell orchestration.** This is
  re-implementing Terramate badly, without change detection.
