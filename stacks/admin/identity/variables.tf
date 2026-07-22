variable "state_bucket" {
  description = "Remote-state bucket holding the eks stack's outputs. Supplied as TF_VAR_state_bucket, mapped from TF_STATE_BUCKET by terramate.config.run.env (ADR-0010)."
  type        = string
}
