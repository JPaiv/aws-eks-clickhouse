# Runbook — Taskfile

[`Taskfile.yml`](../../Taskfile.yml) is the single entrypoint for every workflow
in this repo. Nothing in the docs or CI calls `tofu` or `terramate` directly, so
the Taskfile is always an accurate description of how the stack is operated.
See [ADR-0001](../adr/0001-go-task-as-the-command-interface.md).

```bash
task            # list every available command
task doctor     # print the version of every tool
```

## Stack selection

Every lifecycle task accepts the same three optional filters, and they combine:

| Variable       | Effect                                          | Example                    |
| -------------- | ----------------------------------------------- | -------------------------- |
| `STACK=<path>` | Operate on one stack (`terramate --chdir`)      | `STACK=stacks/admin/eks`    |
| `TAGS=<a,b>`   | Operate on stacks carrying these Terramate tags | `TAGS=eks,clickhouse`      |
| `CHANGED=true` | Operate only on stacks changed vs. the base ref | `CHANGED=true`             |

Anything after `--` is forwarded to OpenTofu:

```bash
task plan STACK=stacks/admin/eks -- -target=module.node_group
```

## Command reference

### Environment

| Task           | Does                                                |
| -------------- | --------------------------------------------------- |
| `doctor`       | Prints the version of every tool the stack relies on |
| `aws:login`    | `aws sso login`, then shows the resolved identity    |
| `aws:logout`   | Ends the SSO session, clears the cached token        |
| `aws:whoami`   | `aws sts get-caller-identity`                        |

### Terramate

| Task          | Does                                                       |
| ------------- | ---------------------------------------------------------- |
| `tm:list`     | Lists the stacks matching the current filters               |
| `tm:generate` | Regenerates the Terramate-managed OpenTofu files           |
| `tm:create`   | Creates a stack — `task tm:create DIR=stacks/dev/eks NAME=EKS TAGS=eks`, then regenerates |

`tm:generate` must be re-run after any change to a `.tm.hcl` file. Generated
files are committed, so `terramate fmt --check` plus a clean `git diff` after
generation is what CI enforces.

### Quality gates

| Task        | Does                                                              |
| ----------- | ----------------------------------------------------------------- |
| `fmt`       | `terramate fmt` + `tofu fmt -recursive`                           |
| `fmt:check` | Same, in check mode — fails instead of rewriting                  |
| `lint`      | `tflint --recursive`, failing on warnings and above               |
| `sec`       | `trivy config` over the whole tree, non-zero exit on findings     |
| `docs`      | Regenerates `README.md` in every module under `modules/`          |
| `validate`  | Backend-less `tofu init` + `tofu validate` in every selected stack |
| `check`     | `fmt:check` + `lint` + `sec` — the gate CI runs                   |

`validate` is deliberately offline: it initialises with `-backend=false`, so
it needs no AWS credentials and no state bucket. That init drops the backend
binding — run `task init` again before the next `plan` or `apply`.

### Lifecycle

| Task      | Does                                                                  |
| --------- | --------------------------------------------------------------------- |
| `init`    | `tofu init`, injecting `TF_STATE_BUCKET` into the S3 backend          |
| `plan`    | `tofu plan -input=false -lock=false`                                  |
| `apply`   | `tofu apply -auto-approve` — prompts for confirmation first           |
| `destroy` | `tofu destroy -auto-approve` in `--reverse` stack order, prompts first |
| `output`  | `tofu output -json`                                                   |

`apply` and `destroy` are the only tasks that mutate anything, and both are
guarded by an interactive prompt naming the target. `plan` uses `-lock=false`
because it never writes state — that keeps concurrent plans from blocking each
other.

`destroy` runs `--reverse` so dependent stacks are torn down before the stacks
they depend on — the state bucket goes last.

The generated backend blocks deliberately omit the bucket name
([ADR-0010](../adr/0010-remote-state-s3-native-locking.md)); `init` injects it
from `TF_STATE_BUCKET` in `devcontainer.env`. On the bootstrap state stack —
the one stack on local state — that extra flag prints a harmless
"backend-config used without a backend" warning.

### Kubernetes

| Task             | Does                                                        |
| ---------------- | ----------------------------------------------------------- |
| `k8s:kubeconfig` | `aws eks update-kubeconfig` for `$CLUSTER_NAME`, shows context |
| `k8s:nodes`      | `kubectl get nodes -o wide`                                 |
| `k8s:pods`       | `kubectl get pods -A`                                       |

`CLUSTER_NAME` and `AWS_REGION` come from `.devcontainer/devcontainer.env`,
which the Taskfile loads via `dotenv` — so the same tasks work outside the
container as long as that file exists.

### Teardown

| Task   | Does                                                                |
| ------ | ------------------------------------------------------------------- |
| `nuke` | `cloud-nuke aws` — deletes **everything** in the account            |

`nuke` prints the caller identity and requires confirmation. It exists because
this is a portfolio stack living in a throwaway account; never point it at an
account that holds anything you care about.

## Typical sessions

**Day-to-day change**

```bash
task aws:login
task tm:generate
task check
task plan CHANGED=true
task apply CHANGED=true
```

**Bringing the cluster up from nothing**

```bash
task aws:login
task init STACK=stacks/bootstrap/state
task apply STACK=stacks/bootstrap/state     # prints state_bucket
# copy the state_bucket output into TF_STATE_BUCKET in .devcontainer/devcontainer.env
task init
task apply TAGS=network
task apply TAGS=eks
task k8s:kubeconfig
task k8s:nodes
```

The bootstrap state stack is applied first and exactly once per account
([ADR-0010](../adr/0010-remote-state-s3-native-locking.md)); everything after
`task init` is the ordinary loop.

**Tearing it back down**

```bash
task destroy
```

## Adding a task

Keep the shape consistent with what is already there:

- `desc:` on everything that is not `internal: true` — it is the `task --list` UI.
- Anything that runs OpenTofu across stacks goes through the internal `_run`
  task, so filters and flag assembly stay in one place.
- Anything destructive gets a `prompt:` naming what it will affect.
- Prefer `{{.CLI_ARGS}}` pass-through over inventing new variables.
