stack {
  name        = "network"
  description = "VPC for the EKS cluster"
  tags        = ["network"]
  after       = ["tag:state"]
  id          = "eb3fe2b7-faa5-4e28-b262-890dd6cd7bc2"
}
