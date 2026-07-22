stack {
  name        = "identity"
  description = "Pod Identity fixed point: ACK iam+eks controller roles, boundary, associations"
  tags        = ["gitops", "identity"]
  after       = ["tag:eks", "tag:fleet"]
  id          = "db34f61b-a486-4bd5-9a47-33717909ca3e"
}
