# TFLint configuration — `task lint` runs `tflint --init` (downloads the
# plugins below) and then `tflint --recursive`.

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

# The generated locals bridge (_terramate_generated_globals.tf) exposes the
# same shared values to every stack; not every stack uses every one.
rule "terraform_unused_declarations" {
  enabled = false
}

plugin "aws" {
  enabled = true
  version = "0.43.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
