# Terraform - EKS Auto Mode + VPC + GitHub OIDC (IaC option B)

Terraform equivalent of [`../eksctl/cluster.yaml`](../eksctl/cluster.yaml). The brief allows
either tool; this repo ships **both**. Built from the official Registry modules
(`terraform-aws-modules/vpc`, `terraform-aws-modules/eks`).

What it creates:

| Piece | Resource |
|---|---|
| Network | VPC, 2 public + 2 private subnets, single NAT GW, ELB discovery tags |
| Cluster | EKS **Auto Mode** (`namegen-cluster`, K8s 1.31) - AWS manages node pools, EBS CSI, LB controller |
| CI/CD auth | GitHub **OIDC Identity Provider** + IAM **Role** (Web Identity trust, `StringEquals`, post-2026-07-15 subject format with numeric IDs) + least-privilege policy via `aws_iam_role_policy_attachment` |
| Cluster access | **EKS Access Entry** mapping the GitHub role to `AmazonEKSClusterAdminPolicy` (+ admin for whoever runs apply) |
| Registry | the `namegen` ECR repository (scan-on-push) |

## Usage

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # fill in the numeric GitHub IDs
terraform init
terraform plan
terraform apply          # ~15-20 min
# wire CI: set the printed github_actions_role_arn as role-to-assume in deploy.yml
aws eks update-kubeconfig --region us-west-2 --name namegen-cluster
kubectl apply -f ../k8s/
terraform destroy        # ALWAYS tear down (~$0.10/hr control plane + nodes + NLB)
```

## Notes

- **`terraform.tfstate` is the source of truth** - don't delete it mid-lifecycle; for teams,
  enable the versioned **S3 backend** in `backend.tf` (then `terraform init` migrates state).
- **The OIDC provider is account-global** - if the account already has
  `token.actions.githubusercontent.com`, set `create_github_oidc_provider = false`.
- **Why numeric GitHub IDs?** GitHub changed the OIDC `sub` claim format on **2026-07-15**;
  trust policies with names only fail with `Not authorized to perform sts:AssumeRoleWithWebIdentity`.
  Fetch them: `curl -s https://api.github.com/repos/<owner>/<repo> | jq '{owner_id: .owner.id, repo_id: .id}'`
- `inline_policy` / `managed_policy_arns` are deprecated - permissions attach via
  `aws_iam_role_policy_attachment`.
