# Globals shared by every stack. Referenced from the generate_hcl blocks in
# gen_tofu.tm.hcl; hand-written stack code reads them through the generated
# locals bridge (_terramate_generated_globals.tf).
#
# Resource names are built with the CloudPosse null-label module from these
# components (ADR-0011): <namespace>-<environment>-<stage>-<name>, e.g.
# per-en1-admin-ack for the ACK admin cluster and per-en1-dev-clickhouse for
# the ClickHouse cluster it will later provision.

globals {
  region = "eu-north-1"

  # null-label components shared by every stack; stage and name are set
  # per-directory (see stacks/admin/globals.tm.hcl).
  namespace   = "per"
  environment = "en1" # eu-north-1

  # Applied to every AWS resource via the provider's default_tags; the
  # per-resource null-label tags (Namespace/Environment/Stage/Name) come on
  # top of these.
  tags = {
    Project   = "aws-eks-clickhouse"
    ManagedBy = "opentofu"
  }
}

globals "tofu" {
  required_version      = ">= 1.12.0"
  aws_provider_version  = "~> 6.0"
  helm_provider_version = "~> 3.0"
}
