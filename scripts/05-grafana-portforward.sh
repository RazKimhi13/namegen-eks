#!/usr/bin/env bash
# Print the Grafana admin password and open a port-forward to the dashboard on :3000.
#
# WHY a port-forward and not a LoadBalancer: a monitoring dashboard has no business being
# on the public internet. Grafana's Service is deliberately ClusterIP, so we tunnel to it.
#
# NOTE: RUN THIS SOMEWHERE WITH A BROWSER.
#    The forward lands on 127.0.0.1 of whatever machine runs the command. AWS CloudShell has
#    no GUI, so port-forwarding there gives you nothing to look at. Use your laptop
#    (Git Bash or WSL - the `export`/`$(...)` syntax below does not work in cmd.exe).
set -euo pipefail
PROFILE=personal
REGION=us-west-2
CLUSTER=namegen-cluster
NS=monitoring
RELEASE=monitoring
PORT=3000

aws eks update-kubeconfig --region "$REGION" --name "$CLUSTER" --profile "$PROFILE" >/dev/null

# The chart stores the generated admin password in a Kubernetes Secret.
PASSWORD=$(kubectl -n "$NS" get secret "${RELEASE}-grafana" \
  -o jsonpath="{.data.admin-password}" | base64 --decode)

cat <<EOF

  Grafana
  -------
  URL:      http://127.0.0.1:$PORT
  user:     admin
  password: $PASSWORD

  Ready-made dashboards ship with the chart - browse Dashboards -> General:
    "Kubernetes / Compute Resources / Cluster"     <- good overview screenshot
    "Kubernetes / Compute Resources / Namespace (Pods)"  <- pick namespace: namegen
    "Node Exporter / Nodes"                         <- CPU / memory / disk per node

  Screenshot at least one of these into screenshots/ for the submission.
  Press Ctrl+C to stop the port-forward.

EOF

kubectl -n "$NS" port-forward "svc/${RELEASE}-grafana" "${PORT}:80"
