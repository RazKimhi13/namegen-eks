# Inputs. Copy terraform.tfvars.example -> terraform.tfvars and fill in the
# account-specific values (GitHub numeric IDs come from
# https://api.github.com/repos/<owner>/<repo> -> .owner.id and .id).

variable "region" {
  description = "AWS region (matches eksctl/cluster.yaml and the CI workflow)"
  type        = string
  default     = "us-west-2"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "namegen-cluster"
}

variable "cluster_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.31"
}

variable "vpc_cidr" {
  description = "CIDR block for the cluster VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "ecr_repository" {
  description = "ECR repository name the CI pipeline pushes to"
  type        = string
  default     = "namegen"
}

# --- GitHub OIDC (CI/CD auth without long-lived keys) ---

variable "github_owner" {
  description = "GitHub org/user that owns the repo"
  type        = string
  default     = "RazKimhi13"
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  default     = "namegen-eks"
}

variable "github_owner_id" {
  description = "NUMERIC GitHub owner ID (required since GitHub's 2026-07-15 OIDC subject-format change; see iam.tf)"
  type        = number
}

variable "github_repo_id" {
  description = "NUMERIC GitHub repository ID (required since GitHub's 2026-07-15 OIDC subject-format change)"
  type        = number
}

variable "github_branch" {
  description = "Branch allowed to assume the deploy role"
  type        = string
  default     = "main"
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub OIDC Identity Provider. Set to false if the account already has one (it is account-global, only one can exist)."
  type        = bool
  default     = true
}
