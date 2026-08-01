#!/usr/bin/env bash
# Create the ECR repository that CI/builds push to. Idempotent.
set -euo pipefail
PROFILE=personal
REGION=us-west-2
REPO=namegen

aws ecr create-repository --repository-name "$REPO" --region "$REGION" --profile "$PROFILE" \
  --image-scanning-configuration scanOnPush=true >/dev/null 2>&1 \
  && echo ">> Created ECR repo '$REPO'." \
  || echo ">> ECR repo '$REPO' already exists."

echo -n ">> Repository URI: "
aws ecr describe-repositories --repository-names "$REPO" --region "$REGION" --profile "$PROFILE" \
  --query 'repositories[0].repositoryUri' --output text
