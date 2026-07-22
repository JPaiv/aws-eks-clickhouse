// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  backend "s3" {
    encrypt      = true
    key          = "stacks/admin/argocd/terraform.tfstate"
    region       = "eu-north-1"
    use_lockfile = true
  }
}
