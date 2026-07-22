module "vpc" {
  source = "../../../modules/vpc"

  name         = module.label.id
  cluster_name = module.label.id
  tags         = module.label.tags
}
