#!/usr/bin/env bash
# Tear EVERYTHING down. Run this whenever you stop working - a running cluster costs money.
# Deletes k8s resources FIRST (releases the NLB + EBS volumes) THEN the cluster stack.
set -euo pipefail
PROFILE=personal
REGION=us-west-2
CLUSTER=namegen-cluster
NS=namegen
cd "$(dirname "$0")/.."

echo ">> Uninstalling the monitoring stack (Grafana + Prometheus)..."
# Ordered teardown. `values.yaml` disables persistence, so there are no monitoring PVCs to
# leak - but uninstall first anyway so nothing is holding cluster resources open.
helm uninstall monitoring -n monitoring 2>/dev/null || true
kubectl delete namespace monitoring --ignore-not-found=true 2>/dev/null || true

echo ">> Deleting k8s resources (releases the NLB + EBS volumes)..."
kubectl delete -f k8s/ --ignore-not-found=true || true
echo ">> Giving the AWS Load Balancer controller a moment to remove the NLB..."
sleep 30

echo ">> Deleting the EKS cluster (whole CloudFormation stack, ~10-15 min)..."
eksctl delete cluster -f eksctl/cluster.yaml --profile "$PROFILE" --wait

echo
echo ">> Cluster deleted. Optional extras:"
echo "   ECR repo:  aws ecr delete-repository --repository-name namegen --force --region $REGION --profile $PROFILE"
echo "   Verify no leftover load balancers / EBS volumes in the $REGION console."
