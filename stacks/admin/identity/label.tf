# Names everything belonging to the ACK admin cluster: per-en1-admin-ack
# (ADR-0011). Stage and name come from stacks/admin/globals.tm.hcl via the
# generated locals bridge, so this block is identical in every admin stack.
module "label" {
  # Git source, not the registry shorthand: the registry resolves this module
  # to a commit-SHA ref that OpenTofu's module getter refuses to fetch.
  source = "git::https://github.com/cloudposse/terraform-null-label.git?ref=0.25.0"

  namespace   = local.namespace
  environment = local.environment
  stage       = local.stage
  name        = local.name
}

# One label per bootstrapped controller: per-en1-admin-ack-iam-controller and
# per-en1-admin-ack-eks-controller.
module "controller_label" {
  for_each = local.controllers

  source = "git::https://github.com/cloudposse/terraform-null-label.git?ref=0.25.0"

  context    = module.label.context
  attributes = [each.key, "controller"]
}

# per-en1-admin-ack-boundary — the permissions boundary every ACK-created
# role must carry (ADR-0012).
module "boundary_label" {
  source = "git::https://github.com/cloudposse/terraform-null-label.git?ref=0.25.0"

  context    = module.label.context
  attributes = ["boundary"]
}
