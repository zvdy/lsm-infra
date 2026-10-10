variable "region" {
  description = "AWS region for the ECR repository."
  type        = string
  default     = "eu-west-1"
}

variable "repository_name" {
  description = "ECR repository name."
  type        = string
  default     = "lsm-rust"
}

variable "github_repository" {
  description = "GitHub repository (owner/name) allowed to push images via OIDC. Empty disables the role."
  type        = string
  default     = "zvdy/lsm-rust"
}

variable "github_ref" {
  description = "Git ref pattern allowed to assume the push role (the OIDC `sub` claim suffix)."
  type        = string
  default     = "ref:refs/tags/v*"
}

variable "create_github_oidc_provider" {
  description = "Create the account-wide GitHub OIDC provider. Set false if one already exists."
  type        = bool
  default     = true
}

variable "untagged_expiry_days" {
  description = "Expire untagged images after this many days."
  type        = number
  default     = 7
}

variable "tags" {
  type    = map(string)
  default = {}
}
