output "cluster_name" {
  description = "EKS cluster name (for aws eks update-kubeconfig)"
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = module.eks.cluster_endpoint
}

output "region" {
  description = "AWS region"
  value       = var.region
}

output "ecr_repository_url" {
  description = "ECR repo the CI pipeline pushes to"
  value       = aws_ecr_repository.namegen.repository_url
}

output "github_actions_role_arn" {
  description = "Set this as the AWS_ROLE_ARN repo variable / role-to-assume in .github/workflows/deploy.yml"
  value       = aws_iam_role.github_actions.arn
}

output "update_kubeconfig" {
  description = "Run this to connect kubectl"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}
