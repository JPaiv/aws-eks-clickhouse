# ADR-0001 — go-task is the only command interface

- **Status:** Accepted
- **Date:** 2026-07-22

## Context

The stack is operated through a handful of tools that each take a long, easy to
get wrong argument list: `terramate run --tags … -- tofu plan -input=false …`,
`aws eks update-kubeconfig --name … --region …`, `trivy config --exit-code 1 …`.

Left undocumented, those invocations end up living in three places that drift
apart: a README, a CI workflow, and whatever people actually type. The
consequences of drift are not cosmetic here — the difference between `plan` and
`apply`, or between one stack and all stacks, is a production change.

A wrapper is also the natural place to put the guard rails: confirmation
prompts, consistent `-input=false`, `--reverse` on destroy.

## Decision

Every workflow goes through `Taskfile.yml`, run by
[go-task](https://taskfile.dev). Documentation and CI call `task <name>` and
never the underlying tool directly.

go-task over the alternatives because it is a single static binary (trivial to
pin in the dev container), its YAML is declarative enough to stay readable, and
it has the two features this repo actually needs: `prompt:` for destructive
tasks and `{{.CLI_ARGS}}` pass-through so escape hatches do not require new
tasks.

Stack selection is uniform across every lifecycle task — `STACK=`, `TAGS=`,
`CHANGED=` — and flag assembly lives in one internal `_run` task rather than
being repeated per command.

## Consequences

- `task --list` is the discoverable, always-current index of what can be done.
- CI and local runs are the same commands, so "works on my machine" failures
  become reproducible.
- One more binary in the image and one more file to keep honest. A task that
  silently rots is worse than no task, so `check` runs in CI.
- Contributors who know Terraform but not this repo have an extra layer to read
  through. Mitigated by [the Taskfile runbook](../runbooks/taskfile.md), and by
  `--dry` printing the exact underlying command.

## Alternatives considered

- **Make.** Universally available, but tab-sensitive syntax, no first-class
  argument passing, and `.PHONY` noise. Its dependency-graph strength is wasted
  here — nothing in this repo is a file-timestamp build.
- **Shell scripts in `scripts/`.** Maximum flexibility, no discoverability, and
  every script re-implements argument parsing and confirmation prompts.
- **Just.** Very close call; go-task won on the built-in `prompt:` support and
  the YAML being easier to extend with per-task `status:` guards.
- **Nothing — document raw commands.** This is what the drift argument above
  rules out.
