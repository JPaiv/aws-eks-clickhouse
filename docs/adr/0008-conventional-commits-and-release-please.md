# ADR-0008 — Conventional Commits and release-please

- **Status:** Accepted
- **Date:** 2026-07-22

## Context

Infrastructure repositories have a version problem that application
repositories mostly do not: there is no artifact to publish, so there is no
natural forcing function for versioning, and it tends not to happen at all.
The result is a repo where "what changed between the state of the cluster last
month and now" can only be answered by reading `git log` and inferring.

That answer matters here specifically. When a ClickHouse cluster starts
misbehaving, the first question is which infrastructure change landed before it
did — and the useful form of that answer is a changelog grouped by what the
change was, not eighty commits in reverse chronological order.

Writing a changelog by hand does not survive contact with a busy week. Deciding
version numbers by hand produces arguments and inconsistency.

## Decision

Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/),
and [release-please](https://github.com/googleapis/release-please) derives the
version and the changelog from them.

- `feat` → minor, `fix`/`perf`/`refactor`/`revert` → patch, `!` or a
  `BREAKING CHANGE:` footer → major. `docs`, `build`, `ci`, `test` and `chore`
  release nothing.
- On every push to `main`, release-please opens or updates a **release PR**
  showing the version it will cut and the changelog it will publish. Merging
  that PR tags the release. Nothing releases without that merge.
- `release-type: simple` — this repo publishes no package, so release-please
  maintains `CHANGELOG.md` and `version.txt` and nothing else.
- The first release is **v1.0.0**, via `initial-version` with an empty manifest.
  A `0.x` line would signal instability the stack does not intend to claim, and
  the pre-1.0 bump rules make `feat` mean minor-or-patch depending on context,
  which is exactly the ambiguity this ADR removes.
- The repo squash-merges, so the PR title is the commit message that gets
  parsed. CI validates the PR title against the same grammar rather than letting
  a malformed title silently produce a wrong version.

The full convention, including the scope vocabulary for this stack, is in
[docs/conventions/commits.md](../conventions/commits.md).

## Consequences

- Version numbers and changelog entries stop being a judgement call at release
  time and become a consequence of how each change was described when it was
  fresh.
- "What changed, and is it likely to explain this incident?" is answerable from
  `CHANGELOG.md` and a git tag.
- The classification moves earlier, to commit time, where it is a small decision
  made with full context — but it is now load-bearing. A `feat` typed as
  `chore` is silently missing from the changelog, and no tooling can detect
  that. The `feat`-vs-`fix` guidance in the conventions doc exists because this
  is the failure mode.
- Contributors have a format to learn, and the PR-title check will reject work
  for a reason unrelated to its content. The error message points at the
  conventions doc to keep that cheap.
- Semantic versioning is a slightly awkward fit for infrastructure: "breaking"
  has to be defined in terms of applies, not APIs. The conventions doc defines
  it as *an apply a reader must plan for* — replacement, recreation, state
  migration, removed output, changed access.
- release-please is a GitHub-coupled tool. Moving off GitHub means replacing it,
  though the commit convention itself is portable and is the part with the
  durable value.

## Alternatives considered

- **No versioning at all.** The honest status quo for most infra repos, and the
  one that makes the incident question unanswerable.
- **Manual `CHANGELOG.md` and hand-picked tags.** Works exactly as long as
  discipline holds, which is until the first busy week.
- **semantic-release.** Equivalent automation, but it releases directly on
  merge to `main`. The release PR is the feature that matters here — it makes
  the version and changelog reviewable *before* the tag exists, rather than
  discovering the wrong bump afterwards.
- **Date-based versioning (CalVer).** Genuinely defensible for infrastructure,
  where "breaking" is fuzzy, and it needs no commit convention. Rejected because
  it conveys nothing about risk: `2026.07.22` does not tell you whether applying
  it will replace your node groups.
- **Conventional Commits without release-please.** Keeps the readable history
  and drops the automation, which is most of the benefit and none of the
  changelog.
