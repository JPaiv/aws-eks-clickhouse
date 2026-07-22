# Cross-stack values arrive via an explicit remote-state read, not implicit
# wiring (ADR-0002).
data "terraform_remote_state" "network" {
  backend = "s3"

  config = {
    bucket = var.state_bucket
    # Must match the generated backend key scheme: <stack path>/terraform.tfstate
    key    = "stacks/admin/network/terraform.tfstate"
    region = local.region
  }
}

module "eks" {
  source = "../../../modules/eks"

  cluster_name = module.label.id
  subnet_ids   = data.terraform_remote_state.network.outputs.private_subnet_ids
  tags         = module.label.tags
}
