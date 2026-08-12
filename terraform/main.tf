# Infrastructure: VPC + EKS (Auto Mode), built from the official Terraform
# Registry modules - the exact pattern taught in s43 (terraform-aws-modules/vpc
# + terraform-aws-modules/eks).
#
#   terraform init
#   terraform plan
#   terraform apply      # ~15-20 min (EKS control plane)
#   terraform destroy    # ALWAYS tear down - control plane bills ~$0.10/hr
#
# This is the Terraform equivalent of eksctl/cluster.yaml (the brief allows
# either; per s44 the submission ships BOTH).

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.13"

  name = "${var.cluster_name}-vpc"
  cidr = var.vpc_cidr

  azs             = local.azs
  private_subnets = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i)]
  public_subnets  = [for i, az in local.azs : cidrsubnet(var.vpc_cidr, 4, i + 8)]

  # One NAT gateway (cheapest HA-enough option for a course project) so the
  # private worker subnets can pull images from ECR.
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_support   = true
  enable_dns_hostnames = true

  # Subnet discovery tags the AWS Load Balancer controller (built into EKS
  # Auto Mode) uses to place the NLB (public) and the pods (private).
  public_subnet_tags = {
    "kubernetes.io/role/elb" = "1"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.31"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true

  # EKS Auto Mode - AWS manages node pools, the EBS CSI driver and the
  # AWS Load Balancer controller (same as autoModeConfig in eksctl/cluster.yaml).
  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose", "system"]
  }

  # Whoever runs `terraform apply` gets cluster-admin (replaces the manual
  # "Access Entry for yourself" console step from the official recipe).
  enable_cluster_creator_admin_permissions = true

  # Access Entry for the GitHub Actions deploy role (s41/s43: the pipeline's
  # IAM role must be mapped into the cluster with AmazonEKSClusterAdminPolicy).
  access_entries = {
    github_actions = {
      principal_arn = aws_iam_role.github_actions.arn

      policy_associations = {
        cluster_admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  tags = {
    Project = "namegen-final-project"
  }
}
