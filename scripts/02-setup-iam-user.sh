#!/usr/bin/env bash
# Official "step-by-step" auth path: create an IAM USER for GitHub Actions + policy + ACCESS KEYS,
# and grant it kubectl RBAC via an EKS access entry. Use with .github/workflows/deploy-accesskeys.yml.
# (The OIDC role in 02-setup-github-oidc.sh is more secure and needs no long-lived keys - prefer it
#  unless the assignment specifically wants access keys. Use ONE of the two.)
# Usage: scripts/02-setup-iam-user.sh <github-org>/<repo>
set -euo pipefail
PROFILE=personal
REGION=us-west-2
CLUSTER=namegen-cluster
USER_NAME=namegen-github-actions
GITHUB_REPO="${1:?usage: 02-setup-iam-user.sh <github-org>/<repo>}"
cd "$(dirname "$0")/.."

ACCOUNT_ID=$(aws sts get-caller-identity --profile "$PROFILE" --query Account --output text)
PERMS=$(sed -e "s#<AWS_ACCOUNT_ID>#$ACCOUNT_ID#g" iam/github-actions-permissions.json)

echo ">> Creating IAM user $USER_NAME ..."
aws iam create-user --profile "$PROFILE" --user-name "$USER_NAME" >/dev/null 2>&1 \
  && echo ">> Created." || echo ">> User already exists."
aws iam put-user-policy --profile "$PROFILE" --user-name "$USER_NAME" \
  --policy-name namegen-ci --policy-document "$PERMS"

echo ">> Creating access key..."
KEY_JSON=$(aws iam create-access-key --profile "$PROFILE" --user-name "$USER_NAME")
AKID=$(echo "$KEY_JSON" | python -c "import sys,json;print(json.load(sys.stdin)['AccessKey']['AccessKeyId'])")
SAK=$(echo "$KEY_JSON"  | python -c "import sys,json;print(json.load(sys.stdin)['AccessKey']['SecretAccessKey'])")

USER_ARN=$(aws iam get-user --profile "$PROFILE" --user-name "$USER_NAME" --query 'User.Arn' --output text)

echo ">> Granting the user kubectl access on the cluster (EKS access entry)..."
aws eks create-access-entry --profile "$PROFILE" --region "$REGION" \
  --cluster-name "$CLUSTER" --principal-arn "$USER_ARN" --type STANDARD >/dev/null 2>&1 || true
aws eks associate-access-policy --profile "$PROFILE" --region "$REGION" \
  --cluster-name "$CLUSTER" --principal-arn "$USER_ARN" \
  --access-scope '{"type":"cluster"}' \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy >/dev/null 2>&1 || true

echo
echo ">> DONE. Add these as GitHub repo secrets (then use deploy-accesskeys.yml):"
echo "     gh secret set AWS_ACCESS_KEY_ID     -R $GITHUB_REPO -b \"$AKID\""
echo "     gh secret set AWS_SECRET_ACCESS_KEY -R $GITHUB_REPO -b \"$SAK\""
echo ">> NOTE: The secret key is shown ONCE. Store it now; never commit it."
