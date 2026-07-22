# IAM roles for every spoke cluster (ADR-0013), named <cluster-name>-<role>:
# per-en1-dev-clickhouse-cluster / per-en1-dev-clickhouse-node. Adding a spoke
# is one entry in local.spokes plus its Git manifests under apps/spokes/.
#
# Deliberately NOT under the /ack/ boundary: these are infrastructure roles
# assumed by AWS services, and the boundary would break nodes (ECR pulls).
# The boundary stays reserved for workload roles born in Git.
#
# Tagging convention (ADR-0013): every cluster-affiliated resource carries a
# Cluster tag naming the EKS cluster it belongs to.

locals {
  # The fleet. Stage/name feed the spoke's null-label; the resulting id is
  # the cluster name used everywhere (roles, tags, Git manifests).
  spokes = {
    dev-clickhouse = { stage = "dev", name = "clickhouse" }
  }
}

# -----------------------------------------------------------------------------
# Spoke cluster roles — assumed by the EKS control plane (Auto Mode)
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "spoke_cluster_assume" {
  statement {
    # TagSession is required by EKS Auto Mode.
    actions = ["sts:AssumeRole", "sts:TagSession"]

    principals {
      type        = "Service"
      identifiers = ["eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "spoke_cluster" {
  for_each = local.spokes

  name               = "${module.spoke_label[each.key].id}-cluster"
  assume_role_policy = data.aws_iam_policy_document.spoke_cluster_assume.json

  tags = merge(module.spoke_label[each.key].tags, {
    Cluster = module.spoke_label[each.key].id
  })
}

locals {
  # The Auto Mode set: compute (built-in Karpenter), block storage (EBS CSI),
  # load balancing and networking are control-plane managed.
  spoke_cluster_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSComputePolicy",
    "arn:aws:iam::aws:policy/AmazonEKSBlockStoragePolicyV2",
    "arn:aws:iam::aws:policy/AmazonEKSLoadBalancingPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSNetworkingPolicy",
  ]

  # Minimal on purpose: Auto Mode moves CNI/CSI permissions to the cluster
  # role, so nodes only join and pull images.
  spoke_node_policies = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodeMinimalPolicy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPullOnly",
  ]
}

resource "aws_iam_role_policy_attachment" "spoke_cluster" {
  for_each = {
    for pair in setproduct(keys(local.spokes), local.spoke_cluster_policies) :
    "${pair[0]}:${basename(pair[1])}" => { spoke = pair[0], policy = pair[1] }
  }

  role       = aws_iam_role.spoke_cluster[each.value.spoke].name
  policy_arn = each.value.policy
}

# -----------------------------------------------------------------------------
# Spoke node roles — Auto Mode nodes, referenced from computeConfig.nodeRoleARN
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "spoke_node_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "spoke_node" {
  for_each = local.spokes

  name               = "${module.spoke_label[each.key].id}-node"
  assume_role_policy = data.aws_iam_policy_document.spoke_node_assume.json

  tags = merge(module.spoke_label[each.key].tags, {
    Cluster = module.spoke_label[each.key].id
  })
}

resource "aws_iam_role_policy_attachment" "spoke_node" {
  for_each = {
    for pair in setproduct(keys(local.spokes), local.spoke_node_policies) :
    "${pair[0]}:${basename(pair[1])}" => { spoke = pair[0], policy = pair[1] }
  }

  role       = aws_iam_role.spoke_node[each.value.spoke].name
  policy_arn = each.value.policy
}
