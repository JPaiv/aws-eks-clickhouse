output "argocd_namespace" {
  description = "Namespace Argo CD runs in"
  value       = helm_release.argo_cd.namespace
}

output "root_application" {
  description = "Name of the root Application — the handover point to GitOps"
  value       = "root"
}
