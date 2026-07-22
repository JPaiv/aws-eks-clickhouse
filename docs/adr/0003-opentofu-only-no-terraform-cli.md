# ADR-0003 — OpenTofu only, no Terraform CLI

- **Status:** Accepted
- **Date:** 2026-07-22

## Context

The dev container shipped both `terraform` and `tofu`. Two interchangeable
executors on `PATH` is an ambiguity, not a feature: whichever one a contributor
happens to type determines which state-file version and which provider lockfile
entries get written.

The argument for keeping the Terraform CLI around was tooling: linters and
documentation generators have historically been built against it.

That turned out not to hold. Every HCL tool in this image parses HCL itself and
never shells out to a `terraform` binary:

| Tool             | Needs a `terraform` binary? |
| ---------------- | --------------------------- |
| `tflint`         | No — own HCL parser         |
| `terraform-docs` | No — own HCL parser         |
| `trivy config`   | No — own HCL parser         |
| `terramate`      | No — runs whatever you name after `--` |

Formatting and validation are covered by `tofu fmt` and `tofu validate`, which
are the same code paths under a different binary name.

## Decision

OpenTofu is the only executor. The Terraform CLI is not installed.

`task fmt` runs `terramate fmt` + `tofu fmt -recursive`; `task lint` runs
TFLint; `task validate` runs `tofu validate` per stack. The VS Code extension is
`OpenTofu.vscode-opentofu` (the official fork of the HashiCorp one) rather than
`hashicorp.terraform`, so the editor's language server does not go looking for a
binary that is not there.

## Consequences

- No ambiguity about which binary produced a state file or a lockfile.
- A smaller image, and one fewer version to keep pinned.
- The license question is settled up front rather than at the point where the
  BUSL terms become relevant.
- Provider lockfiles record OpenTofu's registry addresses. Migrating back to
  Terraform later would require regenerating them.
- Any future tool that genuinely requires `terraform` on `PATH` needs either a
  symlink to `tofu` or a new ADR superseding this one. Some third-party
  integrations still assume the binary name.

## Alternatives considered

- **Keep both, use `tofu`.** The ambiguity above, in exchange for a fallback
  nobody is expected to use.
- **Terraform only.** Rejected on licensing, and because the stack has no
  dependency on Terraform Cloud/Enterprise features.
- **Symlink `terraform` → `tofu`.** Papers over the distinction and produces
  confusing version output. Left as the escape hatch if a tool ever forces it.
