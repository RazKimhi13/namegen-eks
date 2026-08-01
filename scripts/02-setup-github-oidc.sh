#!/usr/bin/env bash
# One-time: create the GitHub OIDC provider + an IAM role GitHub Actions can assume
# (no long-lived keys), and give that role kubectl RBAC via an EKS access entry.
# Usage: scripts/02-setup-github-oidc.sh <github-org>/<repo>
#   e.g. scripts/02-setup-github-oidc.sh RazKimhi13/namegen-eks
set -euo pipefail
PROFILE=personal
REGION=us-west-2
CLUSTER=namegen-cluster
ROLE_NAME=namegen-github-actions
GITHUB_REPO="${1:?usage: 02-setup-github-oidc.sh <github-org>/<repo>}"
cd "$(dirname "$0")/.."

ACCOUNT_ID=$(aws sts get-caller-identity --profile "$PROFILE" --query Account --output text)
echo ">> AWS account: $ACCOUNT_ID   repo: $GITHUB_REPO"

# 1) GitHub OIDC identity provider (idempotent)
if ! aws iam list-open-id-connect-providers --profile "$PROFILE" \
      --query 'OpenIDConnectProviderList[].Arn' --output text | grep -q token.actions.githubusercontent.com; then
  echo ">> Creating GitHub OIDC provider..."
  aws iam create-open-id-connect-provider --profile "$PROFILE" \
    --url https://token.actions.githubusercontent.com \
    --client-id-list sts.amazonaws.com \
    --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 >/dev/null
else
  echo ">> GitHub OIDC provider already exists."
fi

# 2) Role trust + permission policies (fill placeholders from the JSON templates)
TRUST=$(sed -e "s#<AWS_ACCOUNT_ID>#$ACCOUNT_ID#g" \
            -e "s#<GITHUB_ORG>/<GITHUB_REPO>#$GITHUB_REPO#g" iam/github-oidc-trust-policy.json)
PERMS=$(sed -e "s#<AWS_ACCOUNT_ID>#$ACCOUNT_ID#g" iam/github-actions-permissions.json)

aws iam create-role --profile "$PROFILE" --role-name "$ROLE_NAME" \
  --assume-role-policy-document "$TRUST" >/dev/null 2>&1 \
  && echo ">> Created role $ROLE_NAME." \
  || { aws iam update-assume-role-policy --profile "$PROFILE" --role-name "$ROLE_NAME" \
         --policy-document "$TRUST"; echo ">> Updated trust policy on existing role $ROLE_NAME."; }

aws iam put-role-policy --profile "$PROFILE" --role-name "$ROLE_NAME" \
  --policy-name namegen-ci --policy-document "$PERMS"

ROLE_ARN=$(aws iam get-role --profile "$PROFILE" --role-name "$ROLE_NAME" --query 'Role.Arn' --output text)

# 3) EKS access entry so the role has kubectl permissions inside the cluster
echo ">> Granting the role kubectl access on the cluster..."
aws eks create-access-entry --profile "$PROFILE" --region "$REGION" \
  --cluster-name "$CLUSTER" --principal-arn "$ROLE_ARN" >/dev/null 2>&1 || true
aws eks associate-access-policy --profile "$PROFILE" --region "$REGION" \
  --cluster-name "$CLUSTER" --principal-arn "$ROLE_ARN" \
  --access-scope type=cluster \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy >/dev/null 2>&1 || true

echo
echo ">> DONE. Add the role ARN as the GitHub repo secret AWS_ROLE_ARN:"
echo "     $ROLE_ARN"
echo "   (with gh CLI): gh secret set AWS_ROLE_ARN -R $GITHUB_REPO -b \"$ROLE_ARN\""
