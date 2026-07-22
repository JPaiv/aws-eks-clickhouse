# The contract with Git-land (ADR-0013): every spoke Cluster manifest under
# apps/spokes/ references its own role ARNs literally — copy them from
# `task output STACK=stacks/admin/fleet` when creating a spoke.

output "spoke_cluster_role_arns" {
  description = "IAM role ARN per spoke control plane (Cluster spec.roleARN), keyed by spoke"
  value       = { for k, r in aws_iam_role.spoke_cluster : k => r.arn }
}

output "spoke_node_role_arns" {
  description = "IAM role ARN per spoke's Auto Mode nodes (computeConfig.nodeRoleARN), keyed by spoke"
  value       = { for k, r in aws_iam_role.spoke_node : k => r.arn }
}

output "spoke_cluster_names" {
  description = "Cluster names of the fleet, keyed by spoke"
  value       = { for k, l in module.spoke_label : k => l.id }
}
