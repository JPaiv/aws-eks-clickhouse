# ADR-0006 — Drop the Lambda and Rust toolchain

- **Status:** Accepted
- **Date:** 2026-07-22

## Context

The dev container was inherited from a serverless project. It carried a full
Rust-on-Lambda build chain:

| Tool                   | Was there for                                     |
| ---------------------- | ------------------------------------------------- |
| AWS SAM CLI            | Building and locally invoking Lambda functions    |
| `cargo-lambda`         | Cross-compiling Rust Lambda binaries              |
| Zig (`@ziglang/cli`)   | Cross-linking, required by `cargo-lambda`         |
| Rust toolchain (1.97)  | Compiling the functions                           |
| `build-essential`      | `cc`, needed as rustc's linker for host builds    |
| `turbo`                | Monorepo task orchestration for the TS packages   |

This repo builds ClickHouse on EKS. There is no Lambda function, no Rust, and
no TypeScript monorepo in it. Each of those tools was a pinned version to
maintain, a source of build failures (the Rust pin already had a comment
explaining a previous breakage), and a large amount of image weight.

The Rust pin is worth noting: it was raised to 1.97 specifically because the AWS
SDK crates used by the Lambda functions required it. That constraint disappears
with the functions.

## Decision

Remove the Lambda toolchain and everything that existed only to serve it: SAM
CLI, `cargo-lambda`, Zig, the Rust toolchain and `build-essential`. `turbo` goes
with them, as there is no monorepo to orchestrate.

The Dockerfile drops from four build stages to three — the dedicated Rust stage
has no remaining purpose.

Node stays, reduced to `pnpm`, `tsx`, `typescript` and the Claude Code CLI:
useful for ad-hoc scripting and for the tooling around the repo, not for
building anything deployed.

`jq` is added, since Taskfile targets shell out to `aws … --output json`.

## Consequences

- Substantially smaller image and faster rebuilds; five fewer version pins to
  track.
- Nothing in this repo can be compiled from Rust or C without reinstalling a
  toolchain. That is the intended outcome — if a Lambda function is ever needed
  here, it should arrive with its own ADR.
- `cargo build` and `sam build` no longer work in this container. Any inherited
  muscle memory or scripts referring to them will fail loudly rather than
  silently using a stale toolchain.
- The AWS CLI still covers everything the SAM CLI was used for at the
  infrastructure level; SAM's value was local Lambda emulation specifically.

## Alternatives considered

- **Keep them, they are harmless.** They are not: every pinned version is
  maintenance, and the Rust pin had already broken the image once.
- **Keep Rust, drop only the Lambda-specific tools.** Rust's only consumer here
  was `cargo-lambda`. Keeping the compiler and `build-essential` for a
  hypothetical future use is the largest single cost for the least justification.
- **Move the Lambda toolchain to a second, optional dev container.** Reasonable
  if this repo grew a serverless component. It has none, so it would be an empty
  abstraction.
