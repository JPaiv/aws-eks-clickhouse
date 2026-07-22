# EKS control plane. This cluster is the ACK admin cluster: once Argo CD and
# the ACK controllers run here, they own every AWS resource that is not part
# of this bootstrap (ADR-0009). Authentication is API-mode access entries —
# no aws-auth ConfigMap — and workload identity is EKS Pod Identity (agent
# addon in addons.tf), not IRSA.

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# -----------------------------------------------------------------------------
# KMS — one key for both secrets envelope encryption and the log group
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "cluster_key" {
  statement {
    sid       = "AccountRoot"
    actions   = ["kms:*"]
    resources = ["*"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  statement {
    sid = "CloudWatchLogs"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:Describe*",
    ]
    resources = ["*"]

    principals {
      type        = "Service"
      identifiers = ["logs.${data.aws_region.current.region}.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "kms:EncryptionContext:aws:logs:arn"
      values   = ["arn:aws:logs:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/eks/${var.cluster_name}/cluster"]
    }
  }
}

resource "aws_kms_key" "cluster" {
  description         = "Encrypts ${var.cluster_name} Kubernetes secrets and control plane logs"
  enable_key_rotation = true
  policy              = data.aws_iam_policy_document.cluster_key.json
}

resource "aws_kms_alias" "cluster" {
  name          = "alias/eks-${var.cluster_name}"
  target_key_id = aws_kms_key.cluster.key_id
}

# Pre-created at the name EKS expects — otherwise EKS auto-creates the group
# unencrypted and with no retention, outside of state.
resource "aws_cloudwatch_log_group" "cluster" {
  name              = "/aws/eks/${var.cluster_name}/cluster"
  retention_in_days = var.log_retention_days
  kms_key_id        = aws_kms_key.cluster.arn
}

# -----------------------------------------------------------------------------
# Control plane
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "cluster_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "cluster" {
  name               = "${var.cluster_name}-cluster"
  assume_role_policy = data.aws_iam_policy_document.cluster_assume.json
}

resource "aws_iam_role_policy_attachment" "cluster" {
  role       = aws_iam_role.cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_eks_cluster" "this" {
  name    = var.cluster_name
  version = var.kubernetes_version

  role_arn                  = aws_iam_role.cluster.arn
  enabled_cluster_log_types = var.enabled_log_types

  access_config {
    authentication_mode = "API"
    # The human running the bootstrap gets cluster-admin; ACK and Argo CD get
    # their own access entries in a later stack.
    bootstrap_cluster_creator_admin_permissions = true
  }

  # The public endpoint is a deliberate trade-off: this is operated from a
  # devcontainer with no fixed egress IP, access is IAM(SSO)-authenticated,
  # and var.public_access_cidrs exists for when a stable CIDR is available.
  #trivy:ignore:AVD-AWS-0040
  #trivy:ignore:AVD-AWS-0041
  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.cluster.arn
    }
    resources = ["secrets"]
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.cluster,
    aws_cloudwatch_log_group.cluster,
  ]
}
