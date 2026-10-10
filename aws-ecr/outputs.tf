output "repository_url" {
  description = "Use as image.repository in the Helm chart."
  value       = aws_ecr_repository.this.repository_url
}

output "push_role_arn" {
  description = "Role for GitHub Actions to assume with aws-actions/configure-aws-credentials."
  value       = try(aws_iam_role.push[0].arn, null)
}
