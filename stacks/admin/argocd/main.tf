# Argo CD and the single root Application — the last thing OpenTofu installs
# (ADR-0009). Everything Argo reconciles from apps/root onwards is Git's.
#
# No label.tf in this stack: nothing here names an AWS resource; helm release
# names are Kubernetes-side and conventional.

data "terraform_remote_state" "eks" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    # Must match the generated backend key scheme: <stack path>/terraform.tfstate
    key    = "stacks/admin/eks/terraform.tfstate"
    region = local.region
  }
}

resource "helm_release" "argo_cd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  # Chart 10.1.4 ships appVersion v3.4.5 — the same version as the argocd CLI
  # pinned in .devcontainer/Dockerfile. Bump both together.
  version = "10.1.4"

  # Chart defaults are already single-replica/non-HA, which fits the
  # bootstrap node group. Dex is disabled: local admin login only.
  # The server stays ClusterIP behind self-signed TLS; access is
  # `task argocd:ui` (port-forward), so nothing is exposed or downgraded.
  values = [
    yamlencode({
      dex = { enabled = false }
    })
  ]
}

# The root Application (app-of-apps): everything under apps/root in this
# repository. Rendered through the argocd-apps chart so no CRD-aware
# provider is needed at plan time.
resource "helm_release" "root_app" {
  name      = "root"
  namespace = "argocd"

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argocd-apps"
  version    = "2.0.5"

  values = [
    yamlencode({
      applications = {
        root = {
          namespace  = "argocd"
          project    = "default"
          finalizers = ["resources-finalizer.argocd.argoproj.io"]
          source = {
            repoURL        = "https://github.com/JPaiv/aws-eks-clickhouse.git"
            targetRevision = "HEAD"
            path           = "apps/root"
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "argocd"
          }
          syncPolicy = {
            automated   = { prune = true, selfHeal = true }
            syncOptions = ["CreateNamespace=true"]
          }
        }
      }
    })
  ]

  depends_on = [helm_release.argo_cd]
}
