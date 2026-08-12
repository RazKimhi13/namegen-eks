# GitHub Actions -> AWS auth via OIDC + AssumeRole (s41: access keys are NOT
# best practice - permanent and carry no identity; OIDC issues short-lived STS
# credentials per workflow run).
#
# Pieces (mirrors iam/*.json + scripts/02-setup-github-oidc.sh):
#   1. an IAM OIDC Identity Provider for token.actions.githubusercontent.com
#   2. an IAM Role whose trust policy ("Web Identity") only lets THIS repo's
#      main branch assume it
#   3. a least-privilege permissions policy (ECR push + eks:DescribeCluster)
#      attached via aws_iam_role_policy_attachment (s43: inline_policy /
#      managed_policy_arns are deprecated - always use the attachment resource)
#   4. the EKS Access Entry lives in main.tf (module "eks" -> access_entries)

data "aws_caller_identity" "current" {}

# (1) Identity Provider - account-global; create once per account.
resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  # Pinned thumbprint is no longer used for validation by AWS but the argument
  # is still required by the API.
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

locals {
  github_oidc_provider_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"

  # NOTE: GitHub changed the OIDC subject format on 2026-07-15: the `sub` claim
  # now includes the NUMERIC owner ID and repository ID. A trust policy with
  # only the names fails with "Not authorized to perform
  # sts:AssumeRoleWithWebIdentity" (AWS's console template is still stale).
  # Use StringEquals, not StringLike.
  github_oidc_subject = "repo:${var.github_owner}@${var.github_owner_id}/${var.github_repo}@${var.github_repo_id}:ref:refs/heads/${var.github_branch}"
}

# (2) The deploy role GitHub Actions assumes (workflow: role-to-assume).
resource "aws_iam_role" "github_actions" {
  name        = "namegen-github-actions"
  description = "Assumed by the ${var.github_owner}/${var.github_repo} GitHub Actions workflow via OIDC (no long-lived keys)"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = local.github_oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
            "token.actions.githubusercontent.com:sub" = local.github_oidc_subject
          }
        }
      }
    ]
  })
}

# (3) Least-privilege permissions: push the image, read cluster endpoint.
resource "aws_iam_policy" "github_actions" {
  name        = "namegen-github-actions-permissions"
  description = "ECR push/pull for the namegen repo + eks:DescribeCluster for kubeconfig"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ECRAuthToken"
        Effect   = "Allow"
        Action   = "ecr:GetAuthorizationToken"
        Resource = "*"
      },
      {
        Sid    = "ECRPushPull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "arn:aws:ecr:${var.region}:${data.aws_caller_identity.current.account_id}:repository/${var.ecr_repository}"
      },
      {
        Sid      = "EKSDescribeForKubeconfig"
        Effect   = "Allow"
        Action   = "eks:DescribeCluster"
        Resource = "arn:aws:eks:${var.region}:${data.aws_caller_identity.current.account_id}:cluster/${var.cluster_name}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "github_actions" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions.arn
}

# The ECR repository the pipeline pushes to (replaces scripts/00-create-ecr.sh
# when provisioning with Terraform).
resource "aws_ecr_repository" "namegen" {
  name                 = var.ecr_repository
  image_tag_mutability = "MUTABLE"
  force_delete         = true # course project: let terraform destroy remove images too

  image_scanning_configuration {
    scan_on_push = true
  }
}
