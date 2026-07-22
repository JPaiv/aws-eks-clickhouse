# The identity fixed point (ADR-0012): OpenTofu bootstraps Pod Identity for
# exactly two ACK controllers — iam and eks. Together they close the loop:
# the IAM controller creates roles from Git, the EKS controller creates Pod
# Identity associations from Git, so every future controller onboards without
# another OpenTofu change.

data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    # Must match the generated backend key scheme: <stack path>/terraform.tfstate
    key    = "stacks/admin/eks/terraform.tfstate"
    region = local.region
  }
}

data "terraform_remote_state" "fleet" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    # Must match the generated backend key scheme: <stack path>/terraform.tfstate
    key    = "stacks/admin/fleet/terraform.tfstate"
    region = local.region
  }
}

data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id

  # Tagging convention (ADR-0013): every cluster-affiliated resource carries
  # a Cluster tag naming the EKS cluster it belongs to. Everything in this
  # stack belongs to the hub.
  cluster_tag = { Cluster = module.label.id }

  # The two bootstrapped controllers and the policy each one gets. This map is
  # deliberately capped at two forever — anything else belongs in Git as an
  # iam.services.k8s.aws/Role plus an eks.services.k8s.aws/PodIdentityAssociation.
  controllers = {
    iam = { policy_json = data.aws_iam_policy_document.ack_iam_controller.json }
    eks = { policy_json = data.aws_iam_policy_document.ack_eks_controller.json }
  }
}

# EKS Pod Identity trust: the agent on the node exchanges the pod's service
# account token for role credentials through this principal.
data "aws_iam_policy_document" "controller_assume" {
  statement {
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }

    # Confused-deputy guard: only associations in this account may assume.
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [local.account_id]
    }
  }
}

# The controller roles live at the default path "/", deliberately NOT under
# /ack/: the IAM controller's permissions are scoped to role/ack/*, and
# placing its own role there would let it rewrite its own permissions.
resource "aws_iam_role" "controller" {
  for_each = local.controllers

  name               = module.controller_label[each.key].id
  assume_role_policy = data.aws_iam_policy_document.controller_assume.json

  tags = merge(module.controller_label[each.key].tags, local.cluster_tag)
}

resource "aws_iam_role_policy" "controller" {
  for_each = local.controllers

  name   = "ack-${each.key}-controller"
  role   = aws_iam_role.controller[each.key].id
  policy = each.value.policy_json
}

resource "aws_eks_pod_identity_association" "controller" {
  for_each = local.controllers

  cluster_name    = data.terraform_remote_state.eks.outputs.cluster_name
  namespace       = "ack-system"
  service_account = "ack-${each.key}-controller" # the charts' default SA names
  role_arn        = aws_iam_role.controller[each.key].arn

  tags = merge(module.controller_label[each.key].tags, local.cluster_tag)
}

# -----------------------------------------------------------------------------
# Argo CD — the identity the hub deploys into spokes with (ADR-0013)
# -----------------------------------------------------------------------------

# The role needs no IAM permissions at all: Argo authenticates to spokes with
# a presigned sts:GetCallerIdentity token, and authorization comes from the
# per-spoke AccessEntry manifests in Git.
resource "aws_iam_role" "argocd" {
  name               = module.argocd_label.id
  assume_role_policy = data.aws_iam_policy_document.controller_assume.json

  tags = merge(module.argocd_label.tags, local.cluster_tag)
}

# Both controllers deploy/inspect spoke resources; the server needs the same
# credentials for UI/CLI-driven operations. The repo-server does not.
resource "aws_eks_pod_identity_association" "argocd" {
  for_each = toset([
    "argocd-application-controller",
    "argocd-applicationset-controller",
    "argocd-server",
  ])

  cluster_name    = data.terraform_remote_state.eks.outputs.cluster_name
  namespace       = "argocd"
  service_account = each.value
  role_arn        = aws_iam_role.argocd.arn

  tags = merge(module.argocd_label.tags, local.cluster_tag)
}
