#!/usr/bin/env bash
# Create the EKS Auto Mode cluster from the IaC template, then wire up kubectl.
# NOTE: Takes ~15-20 min and starts billing (~$0.10/hr control plane + nodes). Tear down with 99-destroy.sh.
set -euo pipefail
PROFILE=personal
REGION=us-west-2
CLUSTER=namegen-cluster
cd "$(dirname "$0")/.."

echo ">> Creating EKS Auto Mode cluster '$CLUSTER' (~15-20 min)..."
eksctl create cluster -f eksctl/cluster.yaml --profile "$PROFILE"

echo ">> Writing kubeconfig..."
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER" --profile "$PROFILE"

echo ">> Nodes:"
kubectl get nodes
echo ">> Cluster ready. Next: scripts/03-build-and-deploy.sh (manual) or push to GitHub (CI)."
