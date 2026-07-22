# The remote-state contract: the later pod-identity / Argo CD stacks read
# these (ADR-0002). Renaming one is a breaking change for them.

output "cluster_name" {
  description = "Name of the EKS cluster"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64-encoded cluster CA certificate"
  value       = module.eks.cluster_certificate_authority_data
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL of the cluster"
  value       = module.eks.oidc_issuer_url
}

output "node_role_arn" {
  description = "IAM role ARN of the bootstrap node group"
  value       = module.eks.node_role_arn
}
