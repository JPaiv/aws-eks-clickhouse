# Remote-state backend bucket — the one stack that runs on local state,
# because it creates the bucket every other stack stores its state in
# (ADR-0010). Plain resources, no module: this is a one-off, not something to
# reuse.
#
# The bucket name is derived from the account id, so it is reproducible: if
# the local state file is ever lost, the bucket is trivially re-importable.

data "aws_caller_identity" "current" {}

locals {
  bucket_name = "${module.label.id}-${data.aws_caller_identity.current.account_id}"
}

resource "aws_kms_key" "state" {
  description         = "SSE-KMS key for the OpenTofu remote-state bucket"
  enable_key_rotation = true

  tags = module.label.tags
}

resource "aws_kms_alias" "state" {
  name          = "alias/${module.label.id}"
  target_key_id = aws_kms_key.state.key_id
}

# Access logging would need a second bucket that itself wants logging; state
# access is already auditable via CloudTrail.
#trivy:ignore:AVD-AWS-0089
resource "aws_s3_bucket" "state" {
  bucket = local.bucket_name

  # Demo account: `task destroy` must be able to remove the bucket even while
  # it still holds (by then orphaned) state objects.
  force_destroy = true

  tags = module.label.tags
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.state.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket = aws_s3_bucket.state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "state" {
  bucket = aws_s3_bucket.state.id

  # Versioning is the safety net, not an archive: old state versions expire,
  # and failed multipart uploads do not linger.
  rule {
    id     = "expire-noncurrent-state-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}
