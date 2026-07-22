stack {
  name        = "argocd"
  description = "Argo CD install and the root Application - the GitOps handover"
  tags        = ["argocd", "gitops"]
  after       = ["tag:identity"]
  id          = "b4b34aee-5e62-4168-9459-29e1c6d32170"
}
