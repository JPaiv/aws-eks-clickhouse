# Commit conventions

This repo uses [Conventional Commits](https://www.conventionalcommits.org/).
The convention is not cosmetic here — release-please parses these messages to
decide the next version number and to write `CHANGELOG.md`. A commit typed
wrongly produces a wrong release. See
[ADR-0008](../adr/0008-conventional-commits-and-release-please.md).

## Format

```
<type>(<scope>)!: <subject>

<body>

<footer>
```

- **type** — required, from the table below.
- **scope** — optional but expected; the part of the stack affected.
- **!** — marks a breaking change.
- **subject** — imperative mood, lower case, no trailing period, ≤ 72 chars.
  "add node group autoscaling", not "added" or "Adds".

## Types

| Type       | Release effect | Use for                                              |
| ---------- | -------------- | ---------------------------------------------------- |
| `feat`     | **minor**      | New capability — a stack, module, resource, task     |
| `fix`      | **patch**      | Corrects broken behaviour in something already shipped |
| `perf`     | patch          | Same behaviour, better cost or performance           |
| `refactor` | patch          | Restructuring with no behavioural change             |
| `docs`     | none           | Documentation, ADRs, runbooks                        |
| `test`     | none           | Test additions or fixes                              |
| `build`    | none           | Dev container, tool versions, dependencies           |
| `ci`       | none           | GitHub Actions workflows                             |
| `chore`    | none           | Anything else with no user-visible effect            |
| `revert`   | patch          | Reverting a previous commit                          |

Only `feat` and `fix` (and breaking changes) appear in the changelog by default.
`docs`, `build`, `ci` and `refactor` are recorded in a collapsed section.

### `feat` vs `fix` — the distinction that matters

The question is not "how big was the diff", it is **was the previous state
correct?**

- The stack never had a Keeper ensemble, now it does → `feat`.
- The Keeper ensemble was configured with two replicas and could not hold
  quorum → `fix`.
- The node group had no autoscaling and was always meant to → `feat` if it is
  new capability, `fix` if the absence was breaking something already promised.

When genuinely torn, ask whether someone tracking releases would want to see it
under "Features" or "Bug Fixes". If neither fits, it is probably `chore`.

## Scopes

Use the part of the stack the change belongs to:

| Scope          | Covers                                              |
| -------------- | --------------------------------------------------- |
| `devcontainer` | `.devcontainer/`, tool versions                     |
| `taskfile`     | `Taskfile.yml`                                      |
| `ci`           | `.github/workflows/`                                |
| `terramate`    | Stack layout, generation blocks, `.tm.hcl`          |
| `network`      | VPC, subnets, endpoints                             |
| `eks`          | Cluster, node groups, Pod Identity                  |
| `argocd`       | Argo CD install, Applications, sync policy          |
| `ack`          | ACK controllers and the resources they manage       |
| `keeper`       | ClickHouse Keeper                                   |
| `clickhouse`   | ClickHouse operator, installations, storage         |
| `state`        | Remote state backend                                |
| `docs`         | Documentation (when `docs` is not already the type) |

Omit the scope only when a change genuinely spans everything.

## Breaking changes

Two ways to mark one, and both are required to be deliberate — a breaking change
triggers a **major** version bump:

```
feat(eks)!: move node groups to Pod Identity

BREAKING CHANGE: IRSA role annotations are removed. Any workload relying on
the old service-account annotations must be migrated before applying.
```

The `!` makes it visible in `git log --oneline`; the `BREAKING CHANGE:` footer
is what appears in the changelog. Use both.

For infrastructure, "breaking" means an apply that a reader must plan for:
resource replacement, a destroy-and-recreate, a state migration, a removed
output, or a change to how credentials or access are granted.

## Body

Optional for trivial changes, expected for anything non-obvious. Say **why**,
not what — the diff already says what.

Reference issues in the footer:

```
Refs: #42
Closes: #42
```

## Examples

Good:

```
feat(eks): add managed node group for clickhouse workloads
fix(keeper): raise replica count to 3 so the ensemble can hold quorum
build(devcontainer): pin opentofu to 1.12.5
docs(adr): record why terramate replaces terragrunt
refactor(terramate): move backend config into a shared generate block
feat(clickhouse)!: switch storage to s3-backed disks
```

Bad, and why:

```
update stuff                    no type; says nothing
feat: fixes bug                 wrong type, and "fixes" is not a feature
fix(eks): Fixed the cluster.    past tense, capitalised, trailing period
feat(eks): add node group and rewrite the network module and bump tofu
                                three unrelated changes; split them
chore: add clickhouse operator  that is a feat — it will be missing from the changelog
```

## Pull requests

The repo squash-merges, so **the PR title becomes the commit message** and must
itself be a valid conventional commit. Individual commits within a PR are not
parsed by release-please and can be untidy.

One logical change per PR. If the PR title needs an "and", it is two PRs.

## Releasing

Nothing is released manually. On every push to `main`, release-please opens or
updates a release PR that accumulates the changes since the last release and
shows the version it will cut. Merging that PR tags the release and publishes
the changelog.

So: the version bump is decided by the commits you write, and the release
happens when someone merges a PR that says exactly what it will do first.
