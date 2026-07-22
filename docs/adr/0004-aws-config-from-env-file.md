# ADR-0004 — AWS configuration is generated from an env file, not the host

- **Status:** Accepted
- **Date:** 2026-07-22

## Context

The original dev container did two things that do not survive contact with a
second machine or a second reader:

1. `post-start.sh` wrote a hard-coded `~/.aws/config` containing a specific
   company's SSO portal URL, account id and role name.
2. `devcontainer.json` pinned `AWS_PROFILE` to that same company profile.

This is a public portfolio repository, so shipping a real account id and SSO
portal is both a leak of organisational detail and useless to anyone else.

The usual fix — bind-mounting the host's `~/.aws` — was not available either:
the host this repo is developed on has no AWS configuration at all, and
requiring one couples the container to host state that is invisible in the repo.

## Decision

The container is the source of AWS configuration, and its input is a single
git-ignored env file.

- `.devcontainer/devcontainer.env.example` is committed and holds placeholders.
- `initializeCommand` copies it to `.devcontainer/devcontainer.env` on first
  start, so the container never fails on a missing `--env-file` target.
- `devcontainer.json` passes that file to `docker run --env-file`.
- `post-start.sh` regenerates `~/.aws/config` from those variables on **every**
  start, and prints which setup step is still outstanding.
- Placeholder values are detected and treated as "not configured", so a fresh
  clone starts cleanly with no AWS access rather than a broken profile.
- Static credentials (`AWS_ACCESS_KEY_ID`) are supported as an alternative and
  short-circuit SSO config generation.

Nothing is bind-mounted from the host. Two named Docker volumes carry the state
that must survive a rebuild: the SSO token cache (`/root/.aws`) and the
kubeconfig (`/root/.kube`).

## Consequences

- No account identifiers in version control, and a clone works on any machine.
- `devcontainer.env` is the single source of truth. Editing `~/.aws/config`
  inside the container has no lasting effect, since it is overwritten on the
  next start — surprising once, then predictable.
- Changing AWS settings requires a container **restart**, because `--env-file`
  is read at `docker run` time. A rebuild is not needed.
- `aws sso login` survives rebuilds thanks to the token-cache volume, so the
  restart cost is low in practice.
- The volume mount targets are hard-coded to `/root`, matching
  `remoteUser: root`. Changing the remote user requires updating them together —
  called out in a comment at the mount, and in the runbook.
- The placeholder check is string matching against the example values. It is a
  usability affordance, not a security control.

## Alternatives considered

- **Bind-mount the host `~/.aws`.** The standard approach, and the one this
  host cannot use. Also drags host-specific profiles into the container.
- **`containerEnv` in `devcontainer.json`.** Values would have to be committed —
  exactly the problem being solved.
- **Prompt for values in `post-start.sh`.** Lifecycle commands are not reliably
  interactive, and re-entering values on every start is worse than editing a
  file once.
- **A secrets manager / 1Password CLI.** Correct for a team, disproportionate
  for a portfolio repo, and it would add a host dependency of its own.
