# Names the remote-state backend: per-en1-tfstate (ADR-0011). No stage — the
# bucket holds state for every stage in this account.
module "label" {
  # Git source, not the registry shorthand: the registry resolves this module
  # to a commit-SHA ref that OpenTofu's module getter refuses to fetch.
  source = "git::https://github.com/cloudposse/terraform-null-label.git?ref=0.25.0"

  namespace   = local.namespace
  environment = local.environment
  name        = "tfstate"
}
