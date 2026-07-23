module "vpc" {
  source = "../../../modules/vpc"

  name         = module.label.id
  cluster_name = module.label.id
  # Cluster tag: ADR-0013's convention — every cluster-affiliated resource
  # names the EKS cluster it belongs to.
  tags = merge(module.label.tags, { Cluster = module.label.id })
}

# Attached to every spoke's control-plane ENIs via the manifest's
# resourcesVPCConfig.securityGroupIDs. The EKS-managed cluster SG only admits
# the spoke's own nodes, so without this the hub's Argo CD times out dialing
# the spoke's private endpoint (ADR-0013: spokes share the hub VPC — routing
# reaches, the SG must permit).
resource "aws_security_group" "spoke_api" {
  name        = "${module.label.id}-spoke-api"
  description = "Hub-to-spoke Kubernetes API access inside the shared VPC"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "Kubernetes API from the shared VPC (hub Argo CD and admins)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr]
  }

  tags = merge(module.label.tags, { Cluster = module.label.id })
}
