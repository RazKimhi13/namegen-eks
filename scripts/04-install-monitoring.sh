#!/usr/bin/env bash
# Install the Grafana + Prometheus monitoring stack INTO the cluster (project requirement #5).
#
# Uses Helm - the package manager for Kubernetes. `kube-prometheus-stack` is the official
# community chart that bundles Prometheus (collects) + Grafana (visualises) + node-exporter
# + kube-state-metrics. Both Prometheus and Grafana run as pods inside the cluster.
#
# Idempotent: `helm upgrade --install` creates on first run, updates afterwards, so this is
# safe to re-run and safe to call from CI.
#
# Run AFTER the cluster exists (scripts/01-create-cluster.sh).
# Then run scripts/05-grafana-portforward.sh to open the dashboard.
set -euo pipefail
PROFILE=personal
REGION=us-west-2
CLUSTER=namegen-cluster
NS=monitoring
RELEASE=monitoring
cd "$(dirname "$0")/.."

command -v helm >/dev/null 2>&1 || {
  echo "ERROR: helm is not installed."
  echo "  Linux/WSL/CloudShell: curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash"
  echo "  Windows:              winget install Helm.Helm"
  exit 1
}

echo ">> Pointing kubectl at the cluster..."
aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER" --profile "$PROFILE"

# The chart resolves from the repo alias. `helm install` can sometimes pull it implicitly,
# but in practice it errors - so add the repo explicitly (this bit Fadi's class in s41).
echo ">> Adding the prometheus-community Helm repo..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update prometheus-community

echo ">> Installing/upgrading kube-prometheus-stack into namespace '$NS'..."
helm upgrade --install "$RELEASE" prometheus-community/kube-prometheus-stack \
  --namespace "$NS" --create-namespace \
  --values monitoring/values.yaml \
  --wait --timeout 10m

echo
echo ">> Pods:"
kubectl -n "$NS" get pods

echo
echo ">> Done. Next: ./scripts/05-grafana-portforward.sh   (prints the password + opens :3000)"
