output "state_bucket" {
  description = "Remote-state bucket name — copy into TF_STATE_BUCKET in .devcontainer/devcontainer.env"
  value       = aws_s3_bucket.state.id
}

output "kms_key_arn" {
  description = "KMS key encrypting the remote state"
  value       = aws_kms_key.state.arn
}
