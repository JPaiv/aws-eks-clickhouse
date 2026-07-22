# ADR-0011 — Resource naming via CloudPosse null-label

- **Status:** Accepted
- **Date:** 2026-07-22

## Context

The account will eventually hold two clusters — the ACK admin cluster this
repository bootstraps, and the ClickHouse cluster it provisions — plus the
resources around them. Ad-hoc names ("clickhouse", "eks-cluster") stop scaling
the moment a second environment or stage appears, and renaming AWS resources
after the fact means destroy-and-recreate.

## Decision

**Every resource name is built by the CloudPosse
[null-label](https://github.com/cloudposse/terraform-null-label) module from
four components:** `<namespace>-<environment>-<stage>-<name>`.

| Component     | Value        | Meaning                              |
| ------------- | ------------ | ------------------------------------ |
| `namespace`   | `per`        | Owner prefix                         |
| `environment` | `en1`        | Region abbreviation for `eu-north-1` |
| `stage`       | `admin`, `dev`, … | Which plane the resource belongs to |
| `name`        | `ack`, `clickhouse`, … | The thing itself             |

So the admin cluster is **`per-en1-admin-ack`** and the ClickHouse cluster it
will later provision is **`per-en1-dev-clickhouse`**.

The wiring keeps naming policy out of the reusable modules: namespace and
environment are Terramate globals, stage and name are set once per stack
directory (`stacks/admin/globals.tm.hcl`), and each stack instantiates one
`module "label"` whose `id` and `tags` feed the plain string variables of
`modules/vpc` and `modules/eks`. The modules themselves know nothing about
null-label.

The module is pinned to a git tag rather than the registry shorthand: the
registry resolves it to a commit-SHA ref that OpenTofu's module getter
refuses to fetch.

## Consequences

- Names are predictable and collision-free across stages in one account, and
  every resource carries `Namespace`/`Environment`/`Stage`/`Name` tags on top
  of the provider's `default_tags`.
- The two admin stacks cannot disagree on the cluster name — stage and name
  are defined once at the directory level.
- One more third-party module, though a pure-HCL one with no providers and an
  interface that has been stable for years.
- `CLUSTER_NAME` in `devcontainer.env` must match the label output
  (`per-en1-admin-ack`) for `task k8s:kubeconfig` to find the cluster.

## Alternatives considered

- **Hand-assembled `"${var.namespace}-${var.environment}-..."` strings.**
  No dependency, but every stack re-implements ordering, delimiters and tag
  maps, and they drift.
- **Terramate globals computing the full name.** Keeps it in the
  orchestration layer, but loses the generated `tags` map and the
  battle-tested normalisation (case, length limits, delimiters) null-label
  provides.
