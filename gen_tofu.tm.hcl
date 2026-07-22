# Code generation for every stack: backend, provider and a locals bridge.
#
# What runs is what you can read — the generated *.tf files are committed
# (ADR-0002). The `_terramate_generated_` prefix sorts first in a directory
# listing and marks the files as not-hand-edited.

# S3 backend for every stack except the bootstrap ones — the state stack
# creates the bucket the others store their state in, so it necessarily runs
# on local state (ADR-0010).
generate_hcl "_terramate_generated_backend.tf" {
  condition = !tm_contains(terramate.stack.tags, "bootstrap")

  content {
    terraform {
      backend "s3" {
        # `bucket` is intentionally absent: the name is account-derived and
        # lives only in the git-ignored devcontainer.env, so `task init`
        # injects it as -backend-config=bucket=$TF_STATE_BUCKET (ADR-0010).
        key          = "${terramate.stack.path.relative}/terraform.tfstate"
        region       = global.region
        encrypt      = true
        use_lockfile = true # OpenTofu-native S3 locking; no DynamoDB
      }
    }
  }
}

generate_hcl "_terramate_generated_provider.tf" {
  content {
    terraform {
      required_version = global.tofu.required_version

      required_providers {
        aws = {
          source  = "hashicorp/aws"
          version = global.tofu.aws_provider_version
        }
      }
    }

    provider "aws" {
      region = global.region

      default_tags {
        tags = global.tags
      }
    }
  }
}

# Hand-written stack code cannot reference global.* directly; this locals
# bridge is how stacks consume the shared values without duplicating them.
# Each stack feeds them into its null-label module (ADR-0011). Not every
# stack uses every local — terraform_unused_declarations is disabled in
# .tflint.hcl for exactly this reason.
generate_hcl "_terramate_generated_globals.tf" {
  content {
    locals {
      region      = global.region
      namespace   = global.namespace
      environment = global.environment
      stage       = tm_try(global.stage, null)
      name        = tm_try(global.name, null)
    }
  }
}
