# Runbook — Dev Container

The dev container is the only supported environment for this repo. Every tool is
pinned in [`.devcontainer/Dockerfile`](../../.devcontainer/Dockerfile), so a
clean rebuild gives everyone the same toolchain — see
[ADR-0007](../adr/0007-devcontainer-as-the-only-environment.md) for why, and for
what is deliberately absent.

## Contents

| Tool             | Version | Purpose                                          |
| ---------------- | ------- | ------------------------------------------------ |
| `tofu`           | 1.12.5  | OpenTofu — the only IaC executor                 |
| `terramate`      | 0.17.1  | Stack orchestration + HCL code generation        |
| `terramate-ls`   | 0.17.1  | Language server for the VS Code extension        |
| `task`           | 3.52.0  | Task runner — every workflow entrypoint          |
| `tflint`         | 0.64.0  | HCL linter                                       |
| `trivy`          | 0.72.0  | IaC misconfiguration + image scanning            |
| `terraform-docs` | 0.20.0  | Module documentation generator                   |
| `aws`            | 2.35.21 | AWS CLI v2                                       |
| `kubectl`        | 1.36.2  | Kubernetes CLI                                   |
| `helm`           | 4.2.3   | ClickHouse operator / ACK controller installs    |
| `argocd`         | 3.4.5   | Argo CD app sync, status and diff                |
| `gh`             | 2.96.0  | Pull requests, release PRs, CI run inspection    |
| `cloud-nuke`     | 0.41.0  | Account teardown safety net (demo accounts only) |

There is deliberately **no** `terraform`, `terragrunt`, `tfsec`, `sam`,
`cargo-lambda` or Rust toolchain — see
[ADR-0002](../adr/0002-terramate-over-terragrunt.md),
[ADR-0003](../adr/0003-opentofu-only-no-terraform-cli.md),
[ADR-0005](../adr/0005-trivy-replaces-tfsec.md) and
[ADR-0006](../adr/0006-drop-lambda-toolchain.md).

## First start

1. Open the repo in VS Code and choose **Reopen in Container**.
2. On first start, `initializeCommand` copies
   `.devcontainer/devcontainer.env.example` to `.devcontainer/devcontainer.env`
   (git-ignored). The container starts with placeholder AWS values.
3. Fill in `.devcontainer/devcontainer.env` with your account details.
4. **Restart the container** — the env file is read by `docker run --env-file`,
   so a restart is required (a full rebuild is not).
5. `task aws:login` to start an SSO session.

The banner printed on every start tells you which of these steps is outstanding.

## AWS configuration

Nothing is read from the host. The host is not assumed to have `~/.aws` at all —
`.devcontainer/post-start.sh` regenerates `~/.aws/config` from environment
variables on every container start. See
[ADR-0004](../adr/0004-aws-config-from-env-file.md).

### SSO (default)

```dotenv
AWS_PROFILE=clickhouse
AWS_REGION=eu-north-1
AWS_SSO_START_URL=https://your-portal.awsapps.com/start
AWS_SSO_REGION=eu-north-1
AWS_SSO_ACCOUNT_ID=123456789012
AWS_SSO_ROLE_NAME=AdministratorAccess
AWS_SSO_SESSION=sso
```

### Static credentials

Set `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` instead. `post-start.sh`
detects them and skips SSO config generation entirely; the AWS CLI picks the
variables up directly.

### State that survives a rebuild

Two named Docker volumes are mounted, so tokens and cluster context are not lost
when the image is rebuilt:

| Volume                                | Mount        | Holds                    |
| ------------------------------------- | ------------ | ------------------------ |
| `${localWorkspaceFolderBasename}-aws`  | `/root/.aws`  | SSO token cache          |
| `${localWorkspaceFolderBasename}-kube` | `/root/.kube` | kubeconfig / EKS context |

`~/.aws/config` itself is regenerated on every start, so `devcontainer.env`
stays the single source of truth — editing the config file directly has no
lasting effect.

> The mount paths are `$HOME` for `remoteUser: root`. If `remoteUser` changes,
> update the mount targets in `devcontainer.json` to match.

## Common problems

**`docker: --env-file: no such file or directory`**
`initializeCommand` did not run or failed. Create the file manually:

```bash
cp .devcontainer/devcontainer.env.example .devcontainer/devcontainer.env
```

**Banner says `not configured` although the values are filled in**
The placeholder detection matches on `your-sso-portal` and `123456789012`. If
your real account id is one of those strings — it isn't — otherwise the
container was not restarted after editing the env file.

**`aws sso login` opens a browser that cannot reach the container**
The device-code flow prints a URL and a code; open it in the host browser. The
resulting token lands in the `-aws` volume and persists.

**Credentials expired mid-session**
`task aws:login`. No restart needed.

**Tool version drift**
All versions are `ARG`s at the top of the Dockerfile. Bump the `ARG`, rebuild,
and update the table above and `task doctor` output.

## Rebuilding

```bash
# From VS Code: Dev Containers: Rebuild Container
# The named volumes survive; the SSO session does not need re-doing.
```

To discard the persisted AWS/Kubernetes state as well, remove the volumes from
the host:

```bash
docker volume rm aws-eks-clickhouse-aws aws-eks-clickhouse-kube
```
