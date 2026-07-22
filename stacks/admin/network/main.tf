module "vpc" {
  source = "../../../modules/vpc"

  name         = module.label.id
  cluster_name = module.label.id
  # Cluster tag: ADR-0013's convention — every cluster-affiliated resource
  # names the EKS cluster it belongs to.
  tags = merge(module.label.tags, { Cluster = module.label.id })
}
