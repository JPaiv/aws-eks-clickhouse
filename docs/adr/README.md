# Architecture Decision Records

One file per decision, in the order they were taken. Each records the context at
the time, the decision, and the consequences — including the ones that hurt.

ADRs are immutable once accepted. If a decision is revisited, add a new ADR and
mark the old one **Superseded by ADR-NNNN**.

| #                                                | Decision                                     | Status   |
| ------------------------------------------------ | -------------------------------------------- | -------- |
| [0000](0000-record-architecture-decisions.md)    | Record architecture decisions                | Accepted |
| [0001](0001-go-task-as-the-command-interface.md) | go-task is the only command interface        | Accepted |
| [0002](0002-terramate-over-terragrunt.md)        | Terramate replaces Terragrunt                | Accepted |
| [0003](0003-opentofu-only-no-terraform-cli.md)   | OpenTofu only — no Terraform CLI             | Accepted |
| [0004](0004-aws-config-from-env-file.md)         | AWS config is generated from an env file     | Accepted |
| [0005](0005-trivy-replaces-tfsec.md)             | Trivy replaces tfsec                         | Accepted |
| [0006](0006-drop-lambda-toolchain.md)            | Drop the Lambda/Rust toolchain               | Accepted |
| [0007](0007-devcontainer-as-the-only-environment.md) | The dev container is the only environment | Accepted |
| [0008](0008-conventional-commits-and-release-please.md) | Conventional Commits + release-please | Accepted |
| [0009](0009-gitops-bootstrap-boundary.md)       | OpenTofu bootstraps, ACK and Argo CD own day-2 | Accepted, amended by 0013 |
| [0010](0010-remote-state-s3-native-locking.md)  | Remote state: S3 native locking, env-supplied bucket | Accepted |
| [0011](0011-cloudposse-null-label-naming.md)    | Resource naming via CloudPosse null-label    | Accepted |
| [0012](0012-ack-identity-fixed-point.md)        | OpenTofu's identity fixed point: ACK iam + eks controllers | Accepted, amended by 0013 |
| [0013](0013-hub-and-spoke-fleet.md)             | Hub-and-spoke fleet: spoke clusters are Git manifests | Accepted |
| [0014](0014-centralized-observability-on-the-hub.md) | Centralized observability: the hub watches, the spokes ship | Accepted |
| [0015](0015-clickhouse-data-plane.md)           | ClickHouse data plane: S3-backed storage, Pod Identity, per-spoke workloads | Accepted |
| [0016](0016-observability-transport.md)         | Observability transport: spokes reach the hub over an internal NLB | Accepted |

## Format

```markdown
# ADR-NNNN — Title

- **Status:** Proposed | Accepted | Superseded by ADR-NNNN
- **Date:** YYYY-MM-DD

## Context
## Decision
## Consequences
## Alternatives considered
```
