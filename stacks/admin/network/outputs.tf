# The remote-state contract: downstream stacks (stacks/prod/eks) read these
# through a terraform_remote_state data source (ADR-0002). Renaming one is a
# breaking change for them.

output "vpc_id" {
  description = "ID of the cluster VPC"
  value       = module.vpc.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs the EKS cluster and nodes attach to"
  value       = module.vpc.private_subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs for internet-facing load balancers"
  value       = module.vpc.public_subnet_ids
}
