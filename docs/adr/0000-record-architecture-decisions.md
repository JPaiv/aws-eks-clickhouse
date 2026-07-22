# ADR-0000 — Record architecture decisions

- **Status:** Accepted
- **Date:** 2026-07-22

## Context

Most of the choices in this repository are only defensible with their context
attached. "No Terraform CLI in the image" reads as an oversight until you know
that every HCL tool here parses HCL itself. "The AWS profile is regenerated on
every container start" reads as a bug until you know the host has no `~/.aws`
and the repo is public.

That context normally lives in commit messages, pull request threads and
people's heads, and all three decay. The commit message is invisible from the
file it explains; the PR thread is on a platform the repo may outlive; the
person moves on. What is left is code that looks arbitrary, and a successor who
either cargo-cults it or reverts it and rediscovers the original problem.

This is also a portfolio repository. The reasoning behind an infrastructure
choice is the part worth showing — anyone can produce HCL that provisions a
cluster.

## Decision

Every non-obvious decision gets an ADR in `docs/adr/`, in the lightweight
[MADR](https://adr.github.io/madr/)-style format described in
[the index](README.md): Context, Decision, Consequences, Alternatives
considered.

The rules that make them worth reading:

- **Immutable once accepted.** A decision that is revisited gets a *new* ADR,
  and the old one is marked `Superseded by ADR-NNNN`. Editing history to match
  the present destroys the value — the record of what we believed and why.
- **Consequences include the costs.** An ADR that lists only benefits is
  marketing. The section that earns trust is the one admitting what the choice
  makes harder.
- **Alternatives get a fair hearing.** Including the ones that were close calls,
  and why they lost.
- **Numbered sequentially, never renumbered.** Links from code comments,
  runbooks and other ADRs stay valid.

This ADR is numbered 0000 because it is the precondition for the rest, and
starting the substantive decisions at 0001 keeps the numbering stable regardless
of when the meta-decision was written down.

## Consequences

- Reviewers and future maintainers can tell a deliberate constraint from an
  accident, which is the difference between respecting it and removing it.
- Decisions get argued once. When the same question resurfaces, the answer and
  its reasoning are already written.
- ADRs cost time to write at exactly the moment the decision feels obvious —
  which is the moment the context is freshest and the writing is cheapest.
- The set will drift from reality if entries are edited rather than superseded,
  or if decisions are taken without one. The mitigation is social, not
  automated: a change that contradicts an accepted ADR should not merge without
  the superseding ADR in the same commit.
- Not every decision warrants one. Reversible, local choices belong in code
  comments. The bar is: would someone reasonably want to undo this without
  knowing why it exists?

## Alternatives considered

- **Commit messages.** Free, already required, and invisible from the file they
  explain. `git log -S` is not a documentation system.
- **A single `DESIGN.md`.** Easy to start, and it degrades into a document
  describing only the present state — the rejected alternatives and the
  superseded reasoning get edited out, which is precisely the information ADRs
  exist to keep.
- **A wiki.** Lives outside the repo, so it is never updated in the same change
  as the code, and it is not reviewed.
- **Nothing.** The status quo this ADR exists to reject.
