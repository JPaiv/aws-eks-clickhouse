# The contract with Git-land (ADR-0002, ADR-0012): every ACK Role manifest
# must use ack_role_path and reference boundary_policy_arn, or the IAM
# controller's CreateRole call is denied.

output "controller_role_arns" {
  description = "IAM role ARNs of the bootstrapped ACK controllers, by service"
  value       = { for k, r in aws_iam_role.controller : k => r.arn }
}

output "boundary_policy_arn" {
  description = "Permissions boundary ARN every ACK-created role must carry"
  value       = aws_iam_policy.boundary.arn
}

output "ack_role_path" {
  description = "IAM path ACK-created roles must live under"
  value       = "/ack/"
}

output "ack_policy_path" {
  description = "IAM path ACK-created customer-managed policies must live under"
  value       = "/ack/"
}

output "argocd_role_arn" {
  description = "IAM role Argo CD authenticates to spokes with — the principal of every spoke's argocd AccessEntry manifest"
  value       = aws_iam_role.argocd.arn
}
