# lsm-infra

AWS infrastructure for [lsm-rust](https://github.com/zvdy/lsm-rust), kept apart
from the engine and from the Terraform provider so each repo has one job.

| Module | Purpose |
|---|---|
| `aws-ecr/` | Immutable-tag, KMS-encrypted, scan-on-push ECR repository, plus a GitHub OIDC role that lets lsm-rust release builds push images without stored AWS keys |

```sh
cd aws-ecr
terraform init
terraform apply -var region=eu-west-1 -var github_repository=zvdy/lsm-rust
```

Outputs: `repository_url` (use as `image.repository` in the Helm chart) and
`push_role_arn` (set as the `AWS_ECR_PUSH_ROLE_ARN` repository variable in
lsm-rust).

State is local by default. Configure a remote backend (S3 with locking and
encryption) before sharing this with anyone else.
