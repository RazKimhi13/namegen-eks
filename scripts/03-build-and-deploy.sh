#!/usr/bin/env bash
# Manual end-to-end (no CI): build the namegen image -> push to ECR -> deploy to EKS.
# Same steps the GitHub Actions pipeline does, for a quick local run. Run from anywhere.
set -euo pipefail
PROFILE=personal
REGION=us-west-2
CLUSTER=namegen-cluster
NS=namegen
REPO=namegen
cd "$(dirname "$0")/.."

ACCOUNT_ID=$(aws sts get-caller-identity --profile "$PROFILE" --query Account --output text)
REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
IMAGE="$REGISTRY/$REPO:$(git rev-parse --short HEAD 2>/dev/null || date +%s)"

echo ">> Logging in to ECR..."
aws ecr get-login-password --region "$REGION" --profile "$PROFILE" \
  | docker login --username AWS --password-stdin "$REGISTRY"

echo ">> Building + pushing $IMAGE ..."
docker build -t "$IMAGE" .        # Dockerfile + source in repo root
docker push "$IMAGE"

echo ">> Deploying to EKS..."
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER" --profile "$PROFILE"
kubectl apply -f k8s/
kubectl set image deployment/namegen namegen="$IMAGE" -n "$NS"

echo ">> Waiting for rollout..."
kubectl -n "$NS" rollout status statefulset/mongodb --timeout=180s
kubectl -n "$NS" rollout status deployment/namegen --timeout=180s

echo ">> LoadBalancer (NLB EXTERNAL-IP can take 2-3 min to appear):"
kubectl -n "$NS" get svc namegen -o wide
echo ">> Open the EXTERNAL-IP (NLB DNS) in a browser on http:// port 80."
echo
echo ">> Monitoring (project requirement) is a separate step - run:"
echo "     ./scripts/04-install-monitoring.sh     # Helm: Prometheus + Grafana into the cluster"
echo "     ./scripts/05-grafana-portforward.sh    # password + dashboard on :3000"
