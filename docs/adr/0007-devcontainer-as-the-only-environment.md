# ADR-0007 — The dev container is the only supported environment

- **Status:** Accepted
- **Date:** 2026-07-22

## Context

This stack is driven by eleven binaries that all have to agree with each other:
OpenTofu, Terramate, TFLint, Trivy, terraform-docs, the AWS CLI, kubectl, Helm,
cloud-nuke, go-task and Node. Version skew between them is not a theoretical
concern — an OpenTofu minor bump rewrites state, a kubectl more than one minor
off the cluster is unsupported, and a Trivy database change moves findings.

The usual answer is a README section listing versions and a request that people
install them. That produces a machine per contributor, each subtly different,
and failures that reproduce nowhere but the machine they happened on. For
infrastructure code, where the failure mode is a bad apply against a live
account rather than a failing test, that is a worse trade than usual.

Local installs also have to be uninstalled. A machine that has been through
three projects carries three toolchains, and `PATH` decides which one runs.

## Decision

`.devcontainer/` is the supported way to work on this repo, and every tool is
pinned to an exact version via a Dockerfile `ARG`. There is no documented path
for installing the toolchain onto a host.

Specific choices inside that:

- **Multi-stage build.** Tools are fetched in a `debian:bookworm-slim` builder
  and the binaries copied into the runtime image, so `curl`, `unzip` and the
  downloaded archives never reach the final layer.
- **Pinned base image**, `mcr.microsoft.com/devcontainers/base:ubuntu-24.04`.
  The floating `:ubuntu` tag now resolves to 26.04 "resolute", which the
  docker-in-docker feature cannot install onto with its default `moby=true`,
  because Microsoft publishes no moby packages for it. Moving to 26.04 is a
  deliberate change made together with `"moby": false`, not something a rebuild
  should do on its own.
- **kubectl and Helm, but not eksctl.** OpenTofu creates the cluster and
  `aws eks update-kubeconfig` writes the kubeconfig, so eksctl would be a second
  tool capable of mutating cluster infrastructure outside of state. Helm earns
  its place because the ClickHouse operator and the ACK controllers ship as
  charts.
- **cloud-nuke is included.** This is a demo account that gets rebuilt often,
  and a reliable teardown is what makes it safe to experiment. It is exposed
  only behind `task nuke`, which prints the target account and prompts.
- **Node is kept, minimally** — pnpm, tsx, typescript, and the Claude Code CLI —
  for repo tooling and ad-hoc scripting, not for building anything deployed.

Version bumps are one-line `ARG` edits, and the pinned set is mirrored in the
[dev container runbook](../runbooks/devcontainer.md) and by `task doctor`.

## Consequences

- Everyone, including CI, runs identical tool versions. "Works on my machine"
  becomes reproducible.
- Upgrades are explicit, reviewable, and land in a single diff that names the
  old and new version.
- The host stays clean; nothing is installed onto it and nothing needs
  uninstalling.
- Docker is a hard prerequisite, and the first build is slow — several hundred
  megabytes of tooling before any work starts.
- Pins go stale silently. Nothing in the repo warns that OpenTofu 1.12.5 is
  behind; that is a periodic manual sweep, and the runbook table has to be
  updated alongside the Dockerfile or it becomes a lie.
- `remoteUser` is `root`, which is what the persisted-state mount paths in
  `devcontainer.json` are written against. Changing the user means changing the
  mounts in the same edit — see [ADR-0004](0004-aws-config-from-env-file.md).
- Anyone who does work outside the container is unsupported but not blocked:
  the Taskfile reads `.devcontainer/devcontainer.env` via `dotenv`, so the tasks
  themselves still function given a locally installed toolchain.

## Alternatives considered

- **Document versions, install locally.** Zero infrastructure, guaranteed drift.
  The failure mode — an apply from a mismatched OpenTofu — is expensive enough
  to rule it out.
- **asdf / mise version manager.** Genuinely good, and would pin the CLI tools
  from a single `.tool-versions` file. Rejected because it pins only what it
  packages: the OS libraries, the Docker socket wiring and the AWS profile
  generation would still be host-dependent, and several of these tools would
  need custom plugins.
- **Nix / devbox.** The most rigorous reproducibility available, and the steepest
  learning curve of the options. Disproportionate for a repo whose contributors
  are more likely to know Docker than Nix.
- **A plain Dockerfile with `docker run` invocations.** Loses the editor
  integration — the language servers for OpenTofu and Terramate, and the
  extension set — which is a large part of why the container is pleasant to
  work in.
- **Floating `latest` tags.** Rebuilds change the toolchain without a diff,
  which is how the base image broke docker-in-docker in the first place.
