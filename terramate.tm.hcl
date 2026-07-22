# Terramate project configuration.
#
# Terramate orchestrates OpenTofu across the stacks under stacks/ and
# generates the backend/provider boilerplate into each of them (ADR-0002).
# Run `task tm:generate` after editing any .tm.hcl file — generated files are
# committed, and CI fails if generation produces a diff.

terramate {
  required_version = ">= 0.17.0"

  config {
    git {
      # Base ref for `terramate run --changed` (task ... CHANGED=true).
      default_branch = "main"
    }

    # A dirty working tree must not block local plans — the documented dev
    # loop is edit → plan → commit. CI enforces cleanliness instead. The
    # `outdated-code` safeguard stays on: running stale generated code is an
    # error everywhere.
    disable_safeguards = [
      "git-untracked",
      "git-uncommitted",
      "git-out-of-sync",
    ]

    run {
      env {
        # The state bucket name is account-derived and lives only in the
        # git-ignored devcontainer.env (ADR-0010). This maps it to an OpenTofu
        # variable at run time for the stacks that read remote state; tm_try
        # keeps `terramate run` working when the variable is unset (CI).
        TF_VAR_state_bucket = tm_try(env.TF_STATE_BUCKET, "")
      }
    }
  }
}
