# Create EKS Access Entries (from Classroom)

Give the GitHub Actions principal (IAM user OR role) kubectl permissions inside the cluster.
`scripts/02-setup-iam-user.sh` and `scripts/02-setup-github-oidc.sh` both run these for you.

```bash
# 1. Create the Access Entry
aws eks create-access-entry \
    --cluster-name <your-cluster-name> \
    --principal-arn arn:aws:iam::<your-account-id>:role/<your-iam-role> \
    --type STANDARD

# 2. Grant cluster permissions (associate policy)
aws eks associate-access-policy \
    --cluster-name <your-cluster-name> \
    --principal-arn arn:aws:iam::<your-account-id>:role/<your-iam-role> \
    --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
    --access-scope '{"type": "cluster"}'
```

(For an IAM **user** instead of a role, use its user ARN `arn:aws:iam::<acct>:user/<name>`.)
