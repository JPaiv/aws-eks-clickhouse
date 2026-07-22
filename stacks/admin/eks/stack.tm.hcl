stack {
  name        = "eks"
  description = "EKS cluster — the ACK admin cluster"
  tags        = ["eks"]
  after       = ["tag:network"]
  id          = "36fe4b2e-42ba-4987-9735-d36a4ff21585"
}
