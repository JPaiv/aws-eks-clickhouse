// TERRAMATE: GENERATED AUTOMATICALLY DO NOT EDIT

terraform {
  backend "s3" {
    encrypt      = true
    key          = "stacks/admin/identity/terraform.tfstate"
    region       = "eu-north-1"
    use_lockfile = true
  }
}
