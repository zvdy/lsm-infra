provider "aws" {
  region = var.region
  default_tags {
    tags = merge({ app = "lsm-rust", managed-by = "terraform" }, var.tags)
  }
}

data "aws_caller_identity" "current" {}

# Customer-managed key so image layers are encrypted under a key whose use is
# auditable and revocable, rather than the AWS-owned default.
resource "aws_kms_key" "ecr" {
  description             = "ECR encryption for ${var.repository_name}"
  enable_key_rotation     = true
  deletion_window_in_days = var.kms_deletion_window_days
}

resource "aws_kms_alias" "ecr" {
  name          = "alias/${var.repository_name}-ecr"
  target_key_id = aws_kms_key.ecr.key_id
}

resource "aws_ecr_repository" "this" {
  name = var.repository_name
  # Tags cannot be overwritten: a released version always means the same bytes.
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "KMS"
    kms_key         = aws_kms_key.ecr.arn
  }
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Expire untagged images"
      selection = {
        tagStatus   = "untagged"
        countType   = "sinceImagePushed"
        countUnit   = "days"
        countNumber = var.untagged_expiry_days
      }
      action = { type = "expire" }
    }]
  })
}

# ---- keyless CI push via GitHub OIDC (no long-lived AWS keys) ---------------

resource "aws_iam_openid_connect_provider" "github" {
  count          = var.github_repository != "" && var.create_github_oidc_provider ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.github_repository != "" && !var.create_github_oidc_provider ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  oidc_arn = var.github_repository == "" ? null : (
    var.create_github_oidc_provider
    ? aws_iam_openid_connect_provider.github[0].arn
    : data.aws_iam_openid_connect_provider.github[0].arn
  )
}

data "aws_iam_policy_document" "assume" {
  count = var.github_repository == "" ? 0 : 1
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [local.oidc_arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:${var.github_ref}"]
    }
  }
}

resource "aws_iam_role" "push" {
  count                = var.github_repository == "" ? 0 : 1
  name                 = "${var.repository_name}-ecr-push"
  assume_role_policy   = data.aws_iam_policy_document.assume[0].json
  max_session_duration = 3600
}

data "aws_iam_policy_document" "push" {
  count = var.github_repository == "" ? 0 : 1
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:BatchGetImage",
      "ecr:CompleteLayerUpload",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:UploadLayerPart",
    ]
    resources = [aws_ecr_repository.this.arn]
  }
}

resource "aws_iam_role_policy" "push" {
  count  = var.github_repository == "" ? 0 : 1
  name   = "ecr-push"
  role   = aws_iam_role.push[0].id
  policy = data.aws_iam_policy_document.push[0].json
}
