# aws-eks-clickhouse

ClickHouse on EKS with Keeper, OpenTofu, Terramate and ACK.

A production-shaped ClickHouse cluster on AWS. OpenTofu and Terramate bootstrap
just enough to run GitOps — network, cluster, IAM, Argo CD — and then hand over:
Argo CD reconciles from Git and ACK controllers own the remaining AWS resources
from inside the cluster.

The rule that decides which system owns what: **if the cluster must have it in
order to start reconciling, OpenTofu owns it; everything else is a manifest in
Git.** ([ADR-0009](docs/adr/0009-gitops-bootstrap-boundary.md))

> **Status:** the bootstrap stacks (remote state, VPC, EKS) are in place;
> Pod Identity, Argo CD and the GitOps layer are being built. See
> [Roadmap](#roadmap).

## What this is

| Layer             | Choice                                                       |
| ----------------- | ------------------------------------------------------------ |
| Bootstrap IaC     | [OpenTofu](https://opentofu.org), orchestrated by [Terramate](https://terramate.io) |
| Bootstrap scope   | Remote state, network, EKS, Pod Identity, Argo CD + root Application |
| GitOps            | [Argo CD](https://argo-cd.readthedocs.io) — Git is the source of truth after bootstrap |
| AWS resources     | [ACK](https://aws-controllers-k8s.github.io/community/) controllers, reconciled from the cluster |
| Data plane        | ClickHouse + ClickHouse Keeper on Kubernetes                 |
| Command interface | [go-task](https://taskfile.dev) — `Taskfile.yml`             |
| Quality gates     | `tofu fmt`, TFLint, Trivy, terraform-docs                    |
| Releases          | Conventional Commits + release-please                        |
| Environment       | Dev container, every tool version pinned                     |

## Quick start

Requires Docker and VS Code with the Dev Containers extension.

```bash
git clone https://github.com/<you>/aws-eks-clickhouse
code aws-eks-clickhouse       # then: Reopen in Container
```

On first start the container seeds `.devcontainer/devcontainer.env` from the
committed example. Fill in your AWS account details, restart the container, and:

```bash
task              # list every available command
task doctor       # confirm the toolchain
task aws:login    # start an SSO session
```

Nothing is read from your host's `~/.aws` — the container generates its own AWS
profile from that env file. Details in the
[dev container runbook](docs/runbooks/devcontainer.md).

## Working with the stack

Every workflow goes through `task`. The three filters below compose, and apply
to every lifecycle command:

```bash
task plan                             # all stacks
task plan STACK=stacks/admin/eks       # one stack
task plan TAGS=eks,clickhouse         # by Terramate tag
task plan CHANGED=true                # only what changed vs. the base branch
task plan -- -target=module.node_group  # pass flags straight to OpenTofu
```

A typical change:

```bash
task tm:generate    # regenerate Terramate-managed files
task check          # fmt + lint + security scan
task plan CHANGED=true
task apply CHANGED=true
```

`apply` and `destroy` are the only tasks that mutate anything, and both confirm
first. The full command reference is in the
[Taskfile runbook](docs/runbooks/taskfile.md).

## Layout

```
.devcontainer/     Pinned toolchain; AWS profile generated from devcontainer.env
.github/           CI quality gates and release-please
docs/
  adr/             Architecture decision records
  conventions/     Commit format
  runbooks/        Dev container and Taskfile runbooks
stacks/
  bootstrap/state  Remote-state bucket (the one local-state stack)
  admin/network    VPC for the admin cluster
  admin/eks        EKS — the ACK admin cluster (per-en1-admin-ack)
modules/           Hand-written OpenTofu modules: vpc, eks
apps/              Argo CD Applications and ACK manifests        — in progress
Taskfile.yml       The only command interface
```

Names follow the CloudPosse null-label scheme
`<namespace>-<environment>-<stage>-<name>`
([ADR-0011](docs/adr/0011-cloudposse-null-label-naming.md)): the admin
cluster is `per-en1-admin-ack`, and the ClickHouse cluster it will provision
is `per-en1-dev-clickhouse`.

`stacks/` stops where GitOps starts. Anything under `apps/` is reconciled by
Argo CD and never appears in a `tofu plan`.

## Design decisions

Each of these is an ADR with the context, the trade-off and what it costs:

- [ADR-0000](docs/adr/0000-record-architecture-decisions.md) — Record architecture decisions
- [ADR-0001](docs/adr/0001-go-task-as-the-command-interface.md) — go-task is the only command interface
- [ADR-0002](docs/adr/0002-terramate-over-terragrunt.md) — Terramate replaces Terragrunt
- [ADR-0003](docs/adr/0003-opentofu-only-no-terraform-cli.md) — OpenTofu only, no Terraform CLI
- [ADR-0004](docs/adr/0004-aws-config-from-env-file.md) — AWS config generated from an env file, not the host
- [ADR-0005](docs/adr/0005-trivy-replaces-tfsec.md) — Trivy replaces tfsec
- [ADR-0006](docs/adr/0006-drop-lambda-toolchain.md) — Drop the Lambda and Rust toolchain
- [ADR-0007](docs/adr/0007-devcontainer-as-the-only-environment.md) — The dev container is the only supported environment
- [ADR-0008](docs/adr/0008-conventional-commits-and-release-please.md) — Conventional Commits and release-please
- [ADR-0009](docs/adr/0009-gitops-bootstrap-boundary.md) — OpenTofu bootstraps, ACK and Argo CD own day-2
- [ADR-0010](docs/adr/0010-remote-state-s3-native-locking.md) — Remote state: S3 native locking, env-supplied bucket
- [ADR-0011](docs/adr/0011-cloudposse-null-label-naming.md) — Resource naming via CloudPosse null-label

## Roadmap

**Foundation**

- [x] Dev container — OpenTofu, Terramate, kubectl, Helm, Argo CD, Trivy, all pinned
- [x] `Taskfile.yml` as the single command interface
- [x] Host-independent AWS configuration
- [x] Runbooks, commit conventions and ADRs
- [x] CI quality gates and release-please

**Bootstrap — OpenTofu / Terramate**

- [x] Remote state backend (S3 with native `use_lockfile` locking)
- [x] Network stack — VPC, subnets, endpoints
- [x] EKS cluster stack — control plane, bootstrap node group, Pod Identity agent
- [ ] EKS Pod Identity for the ACK controllers and Argo CD
- [ ] Argo CD install and the root Application

**GitOps — Argo CD / ACK**

- [ ] ACK controllers — S3, IAM, and whatever ClickHouse turns out to need
- [ ] ClickHouse Keeper ensemble
- [ ] ClickHouse cluster — sharding, replication, S3-backed storage
- [ ] Observability — metrics, logs, dashboards
- [ ] Teardown ordering — drain Applications before `task destroy`

## License

See [LICENSE](LICENSE).
