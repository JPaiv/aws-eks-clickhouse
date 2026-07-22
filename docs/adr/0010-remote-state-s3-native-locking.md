# ADR-0010 — Remote state: S3 with native locking, bucket name from the environment

- **Status:** Accepted
- **Date:** 2026-07-22

## Context

Splitting the bootstrap into multiple stacks (ADR-0002) requires remote state:
the eks stack reads the network stack's outputs through a
`terraform_remote_state` data source, which needs a backend both stacks agree
on. That backend is itself an AWS resource, which creates a bootstrap ordering
problem — something has to create the bucket before any stack can use it — and
a configuration problem: backend blocks cannot reference variables, so the
bucket name has to reach every stack some other way.

The bucket name contains the AWS account id (for global uniqueness), and this
is a public repository.

## Decision

**A local-state bootstrap stack creates the bucket; every other stack gets a
Terramate-generated S3 backend whose bucket name is injected from the
environment at `init` time.**

Concretely:

- `stacks/bootstrap/state` (tags `state`, `bootstrap`) creates the bucket —
  versioned, SSE-KMS encrypted, public access blocked — and runs on **local
  state**. Its state file is git-ignored; the bucket name is derived from the
  account id, so the stack is trivially re-importable if that file is lost.
- Locking uses OpenTofu's native S3 lockfile (`use_lockfile = true`). No
  DynamoDB table.
- The generated `backend "s3"` block deliberately **omits `bucket`**. The name
  lives in the git-ignored `devcontainer.env` as `TF_STATE_BUCKET`, and
  `task init` passes it as `-backend-config=bucket=...`.
- Stacks that read remote state receive the same value as an OpenTofu variable
  through `terramate.config.run.env` (`TF_VAR_state_bucket`), because data
  sources — unlike backend blocks — can use variables.
- Backend generation is conditional on the stack **not** carrying the
  `bootstrap` tag, which is what keeps the state stack on local state.

## Consequences

- Code generation stays deterministic: `terramate generate` produces the same
  output with or without an environment, so the CI gate that diffs generated
  files needs no AWS context and the account id never appears in the repo.
- Bringing the stack up from nothing gains one manual step: apply the
  bootstrap stack, copy its `state_bucket` output into `devcontainer.env`,
  then `task init`. It is one copy-paste, done once per account.
- Running `task init` on the bootstrap stack prints a warning (backend-config
  flag without a backend); it is harmless and documented in the runbook.
- `task destroy` (reverse run order) tears the bucket down last;
  `force_destroy` lets that succeed even while the bucket still holds the (by
  then orphaned) state objects of the other stacks.
- Forgetting to set `TF_STATE_BUCKET` fails loudly: `init` asks for a bucket
  interactively with `-input=false`, and the eks stack's remote-state read
  errors on an empty bucket name.

## Alternatives considered

- **Commit the bucket name as a Terramate global.** Simplest wiring, and what
  most Terramate setups do. Rejected because it embeds the account id in a
  public repo and forces a second commit cycle after the bootstrap apply.
- **DynamoDB lock table.** The historical default, and one more resource to
  bootstrap. Obsolete: OpenTofu ≥ 1.10 locks natively via a conditional S3
  write.
- **Create the bucket out-of-band (CLI one-liner in the runbook).** Fewer
  moving parts, but the backend then rests on an undocumented resource with
  none of the encryption/lifecycle settings under review.
