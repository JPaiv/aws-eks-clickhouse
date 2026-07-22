# The helm requirement itself is generated: argocd-tagged stacks get an
# aws+helm required_providers block from gen_tofu.tm.hcl (a module may
# declare required_providers only once).
#
# Provider configuration is evaluated lazily: `task validate` never dials the
# cluster; only plan/apply of THIS stack needs it reachable.
# Helm provider v3 syntax: kubernetes/exec are attributes, not blocks.
provider "helm" {
  kubernetes = {
    host                   = data.terraform_remote_state.eks.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(data.terraform_remote_state.eks.outputs.cluster_certificate_authority_data)

    exec = {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks", "get-token",
        "--cluster-name", data.terraform_remote_state.eks.outputs.cluster_name,
        "--region", local.region,
        "--output", "json",
      ]
    }
  }
}
