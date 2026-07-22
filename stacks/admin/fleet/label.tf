# Per-spoke naming (ADR-0011, ADR-0013): each spoke's IAM roles are named
# <cluster-name>-<role-name>, e.g. per-en1-dev-clickhouse-cluster. The spoke
# ids come from local.spokes in main.tf.
module "spoke_label" {
  for_each = local.spokes

  # Git source, not the registry shorthand: the registry resolves this module
  # to a commit-SHA ref that OpenTofu's module getter refuses to fetch.
  source = "git::https://github.com/cloudposse/terraform-null-label.git?ref=0.25.0"

  namespace   = local.namespace
  environment = local.environment
  stage       = each.value.stage
  name        = each.value.name
}
