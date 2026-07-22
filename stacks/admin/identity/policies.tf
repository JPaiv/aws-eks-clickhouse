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
# ACK EKS controller — turns Git manifests into Pod Identity associations
# -----------------------------------------------------------------------------

# Narrowed from ACK's recommended eks:* on "*": this controller exists solely
# to manage Pod Identity associations on this one cluster. Cluster and node
# group reconciliation stays in OpenTofu (ADR-0009), so ec2:DescribeSubnets
# from the recommended policy is deliberately absent.
#trivy:ignore:AVD-AWS-0057
data "aws_iam_policy_document" "ack_eks_controller" {
  statement {
    sid = "PodIdentityAssociations"
    actions = [
      "eks:CreatePodIdentityAssociation",
      "eks:DescribePodIdentityAssociation",
      "eks:UpdatePodIdentityAssociation",
      "eks:DeletePodIdentityAssociation",
      "eks:ListPodIdentityAssociations",
      "eks:DescribeCluster",
      "eks:TagResource",
      "eks:UntagResource",
      "eks:ListTagsForResource",
    ]
    resources = [
      "arn:aws:eks:${local.region}:${local.account_id}:cluster/${data.terraform_remote_state.eks.outputs.cluster_name}",
      "arn:aws:eks:${local.region}:${local.account_id}:podidentityassociation/${data.terraform_remote_state.eks.outputs.cluster_name}/*",
    ]
  }

  # PassRole is its own statement: the PassedToService condition key is absent
  # on read calls and would deny them if merged with the statement below.
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

  statement {
    sid = "ReadAckRoles"
    actions = [
      "iam:GetRole",
      "iam:ListAttachedRolePolicies",
    ]
    resources = ["arn:aws:iam::${local.account_id}:role/ack/*"]
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

  tags = module.boundary_label.tags
}
