# Controller permission policies and the boundary for ACK-created roles.
#
# Scoping strategy (ADR-0012): ACK's recommended policies grant on
# Resource "*"; here every statement is pinned to the /ack/ path — the path is
# part of the ARN, so role/ack/* only ever matches roles under /ack/ and no
# extra condition is needed. Wildcards below the path are unavoidable: the
# whole point is that ACK creates roles OpenTofu has never heard of.

# -----------------------------------------------------------------------------
# ACK IAM controller — creates the roles Git asks for, nothing more
# -----------------------------------------------------------------------------

# Narrowed from ACK's recommended policy: user/group/OIDC-provider actions are
# dropped (nothing in this stack manages them from Git), and
# iam:DeleteRolePermissionsBoundary is never granted — the boundary must not
# be strippable by the controller it constrains.
#trivy:ignore:AVD-AWS-0057
data "aws_iam_policy_document" "ack_iam_controller" {
  statement {
    sid = "RoleLifecycle"
    actions = [
      "iam:GetRole",
      "iam:DeleteRole",
      "iam:UpdateRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:ListRoleTags",
      "iam:ListRolePolicies",
      "iam:GetRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      # Attaching a broad managed policy is not an escalation: the permissions
      # boundary below caps whatever gets attached.
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:ListAttachedRolePolicies",
    ]
    resources = ["arn:aws:iam::${local.account_id}:role/ack/*"]
  }

  # Creating a role — or re-pointing an existing one's boundary — only works
  # with the OpenTofu-owned boundary attached. A Git manifest that omits it
  # gets AccessDenied.
  statement {
    sid = "CreateRoleOnlyWithBoundary"
    actions = [
      "iam:CreateRole",
      "iam:PutRolePermissionsBoundary",
    ]
    resources = ["arn:aws:iam::${local.account_id}:role/ack/*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PermissionsBoundary"
      values   = [aws_iam_policy.boundary.arn]
    }
  }

  statement {
    sid = "PolicyLifecycle"
    actions = [
      "iam:GetPolicy",
      "iam:CreatePolicy",
      "iam:DeletePolicy",
      "iam:GetPolicyVersion",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicyVersion",
      "iam:ListPolicyVersions",
      "iam:ListPolicyTags",
      "iam:TagPolicy",
      "iam:UntagPolicy",
    ]
    resources = ["arn:aws:iam::${local.account_id}:policy/ack/*"]
  }
}

# -----------------------------------------------------------------------------
# ACK EKS controller — the fleet factory (ADR-0013)
# -----------------------------------------------------------------------------

# Widened from the Pod-Identity-only scope of ADR-0012: hub-and-spoke means
# this controller creates and manages entire spoke clusters from Git. Still
# narrowed from ACK's recommended eks:* on "*": everything is pinned to the
# per-en1-* naming scheme, cluster creation demands the fleet tagging
# convention, and the hub itself is protected by an explicit Deny.
#trivy:ignore:AVD-AWS-0057
data "aws_iam_policy_document" "ack_eks_controller" {
  statement {
    sid = "FleetClusterLifecycle"
    actions = [
      "eks:DescribeCluster",
      "eks:DeleteCluster",
      "eks:UpdateClusterConfig",
      "eks:UpdateClusterVersion",
      "eks:DescribeUpdate",
      "eks:ListUpdates",
      "eks:CreateAccessEntry",
      "eks:ListAccessEntries",
      "eks:CreatePodIdentityAssociation",
      "eks:ListPodIdentityAssociations",
    ]
    resources = ["arn:aws:eks:${local.region}:${local.account_id}:cluster/${local.namespace}-${local.environment}-*"]
  }

  # Creating a cluster requires the Cluster tag (ADR-0013's tagging
  # convention): a Git manifest that omits it gets AccessDenied, so every
  # spoke is attributable from day one.
  statement {
    sid       = "CreateClusterWithClusterTag"
    actions   = ["eks:CreateCluster"]
    resources = ["arn:aws:eks:${local.region}:${local.account_id}:cluster/${local.namespace}-${local.environment}-*"]

    condition {
      test     = "StringLike"
      variable = "aws:RequestTag/Cluster"
      values   = ["${local.namespace}-${local.environment}-*"]
    }
  }

  # Tagging authorizes against the ARN of the resource being tagged, so the
  # cluster/* pin alone denies tagging access entries and Pod Identity
  # associations — each resource type needs its own ARN form here.
  statement {
    sid = "FleetTagging"
    actions = [
      "eks:TagResource",
      "eks:UntagResource",
      "eks:ListTagsForResource",
    ]
    resources = [
      "arn:aws:eks:${local.region}:${local.account_id}:cluster/${local.namespace}-${local.environment}-*",
      "arn:aws:eks:${local.region}:${local.account_id}:access-entry/${local.namespace}-${local.environment}-*/*",
      "arn:aws:eks:${local.region}:${local.account_id}:podidentityassociation/${local.namespace}-${local.environment}-*/*",
    ]
  }

  statement {
    sid = "FleetAccessEntries"
    actions = [
      "eks:DescribeAccessEntry",
      "eks:UpdateAccessEntry",
      "eks:DeleteAccessEntry",
      "eks:ListAssociatedAccessPolicies",
      "eks:AssociateAccessPolicy",
      "eks:DisassociateAccessPolicy",
    ]
    resources = ["arn:aws:eks:${local.region}:${local.account_id}:access-entry/${local.namespace}-${local.environment}-*/*"]
  }

  statement {
    sid = "FleetPodIdentityAssociations"
    actions = [
      "eks:DescribePodIdentityAssociation",
      "eks:UpdatePodIdentityAssociation",
      "eks:DeletePodIdentityAssociation",
    ]
    resources = ["arn:aws:eks:${local.region}:${local.account_id}:podidentityassociation/${local.namespace}-${local.environment}-*/*"]
  }

  # The hub must not be mutable from Git: the per-en1-* wildcard above would
  # match it, so the destructive actions are explicitly denied on it.
  # Pod Identity associations ON the hub remain allowed — that is the fixed
  # point working as designed.
  statement {
    sid    = "ProtectTheHub"
    effect = "Deny"
    actions = [
      "eks:DeleteCluster",
      "eks:UpdateClusterConfig",
      "eks:UpdateClusterVersion",
    ]
    resources = ["arn:aws:eks:${local.region}:${local.account_id}:cluster/${data.terraform_remote_state.eks.outputs.cluster_name}"]
  }

  # PassRole is its own statement per condition key: absent on read calls,
  # a merged statement would deny them.
  statement {
    sid       = "PassAckRolesToPodIdentity"
    actions   = ["iam:PassRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/ack/*"]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["pods.eks.amazonaws.com"]
    }
  }

  # Spoke creation passes the per-spoke fleet roles (stacks/admin/fleet).
  # The cluster role is consumed by the EKS control plane.
  statement {
    sid       = "PassFleetClusterRolesToEks"
    actions   = ["iam:PassRole"]
    resources = values(data.terraform_remote_state.fleet.outputs.spoke_cluster_role_arns)

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["eks.amazonaws.com"]
    }
  }

  # The node role's ultimate consumer under Auto Mode is EC2 — EKS evaluates
  # the pass as PassedToService=ec2.amazonaws.com, so eks.amazonaws.com alone
  # gets AccessDenied on CreateCluster. Both services stay listed to cover
  # every point EKS re-evaluates the pass.
  statement {
    sid       = "PassFleetNodeRoles"
    actions   = ["iam:PassRole"]
    resources = values(data.terraform_remote_state.fleet.outputs.spoke_node_role_arns)

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["eks.amazonaws.com", "ec2.amazonaws.com"]
    }
  }

  statement {
    sid = "ReadAckRoles"
    actions = [
      "iam:GetRole",
      "iam:ListAttachedRolePolicies",
    ]
    resources = ["arn:aws:iam::${local.account_id}:role/ack/*"]
  }

  # Cluster creation validates the shared-VPC networking, and the first EKS
  # cluster created by a principal may create the service-linked role.
  statement {
    sid = "NetworkReads"
    actions = [
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
      "ec2:DescribeSecurityGroups",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "EksServiceLinkedRole"
    actions   = ["iam:CreateServiceLinkedRole"]
    resources = ["arn:aws:iam::${local.account_id}:role/aws-service-role/eks.amazonaws.com/*"]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["eks.amazonaws.com"]
    }
  }
}

# -----------------------------------------------------------------------------
# Permissions boundary for every ACK-created role
# -----------------------------------------------------------------------------

# The blast-radius ceiling for roles born in Git: whatever policies the IAM
# controller attaches, the effective permissions never exceed this. The key
# property is what is missing — no iam:* actions at all, so an ACK-created
# role can never mint identity. Widening this boundary is a deliberate,
# reviewed OpenTofu change (expected when the ClickHouse apps land); ACK
# itself cannot touch it.
#
# s3:* below is the outer bound, scoped to label-prefixed buckets — the
# fine-grained grants live in the ACK-created roles this bounds.
#trivy:ignore:AVD-AWS-0057
#trivy:ignore:AVD-AWS-0345
data "aws_iam_policy_document" "boundary" {
  # ClickHouse data disks and whatever the future s3-controller role needs;
  # every bucket in this project is label-prefixed (ADR-0011).
  statement {
    sid     = "S3WithinNamePrefix"
    actions = ["s3:*"]
    resources = [
      "arn:aws:s3:::${local.namespace}-${local.environment}-*",
      "arn:aws:s3:::${local.namespace}-${local.environment}-*/*",
    ]
  }

  # Data-plane use of SSE-KMS keys; key ARNs are unknowable at bound time.
  statement {
    sid = "KmsDataPlane"
    actions = [
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
    ]
    resources = ["*"]
  }

  statement {
    sid = "Logs"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]
    resources = ["arn:aws:logs:${local.region}:${local.account_id}:log-group:*"]
  }

  # Read-only EC2 metadata (subnets, ENIs) for future controllers.
  statement {
    sid       = "Ec2ReadOnly"
    actions   = ["ec2:Describe*"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "boundary" {
  name        = module.boundary_label.id
  description = "Permissions boundary required on every ACK-created role (ADR-0012)"
  policy      = data.aws_iam_policy_document.boundary.json

  tags = merge(module.boundary_label.tags, local.cluster_tag)
}
