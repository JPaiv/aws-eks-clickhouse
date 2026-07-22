# Core addons. Versions resolve to the newest compatible release at plan
# time — a demo repo has no business babysitting addon version pins.
#
# eks-pod-identity-agent is here on purpose: workload identity for the ACK
# controllers and Argo CD is EKS Pod Identity (ADR-0009), so the later
# pod-identity stack only adds associations, never touches the cluster.

locals {
  # Addons that schedule pods need nodes to exist first.
  addons = {
    "vpc-cni"                = { needs_nodes = false }
    "kube-proxy"             = { needs_nodes = false }
    "coredns"                = { needs_nodes = true }
    "eks-pod-identity-agent" = { needs_nodes = true }
  }
}

data "aws_eks_addon_version" "this" {
  for_each = local.addons

  addon_name         = each.key
  kubernetes_version = aws_eks_cluster.this.version
  most_recent        = true
}

resource "aws_eks_addon" "this" {
  for_each = local.addons

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.key
  addon_version               = data.aws_eks_addon_version.this[each.key].version
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags

  depends_on = [aws_eks_node_group.this]
}
