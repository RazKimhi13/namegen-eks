# DevOps - Step by Step (official, from Classroom "Practice Project" post)

The instructor's 11-step recipe for the project. Our scaffold implements all of it.

1. Create your own repo
2. Copy app source code
3. Add a folder containing your eksctl yaml
4. Create the EKS cluster using **`eksctl create`** (CloudShell)
5. Create an **IAM User** for GitHub Actions + an **IAM Policy** + **Access Keys**
6. Save the secrets in the GitHub repo secrets
7. Create an EKS **Access Entry** for the GitHub Actions user with **`AmazonEKSClusterAdminPolicy`**
8. Add a folder with your Kubernetes manifests: App Deployment, DB StatefulSet, StorageClass (gp3)
9. Create the GitHub Actions workflow
10. Test
11. Delete the cluster using **`eksctl delete`** (CloudShell)

> **Auth note:** the official recipe (steps 5-7) uses an **IAM user + access keys** stored as GitHub
> secrets. Our repo supports that (`scripts/02-setup-iam-user.sh` + `.github/workflows/deploy-accesskeys.yml`)
> AND a more-secure **OIDC role** with no long-lived keys (`scripts/02-setup-github-oidc.sh` +
> `.github/workflows/deploy.yml`) - the "secure role" upgrade Fadi flagged for "next week". Use whichever
> your submission requires; both end at the same EKS Access Entry with `AmazonEKSClusterAdminPolicy`.
