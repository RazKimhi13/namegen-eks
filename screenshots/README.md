# Screenshots

All taken during the live deploys on AWS (us-west-2). Details and raw command output:
[`DEPLOY-EVIDENCE.md`](DEPLOY-EVIDENCE.md).

| File | Shows |
|---|---|
| `03-live-nlb-landing.png` | the app served over the internet-facing **NLB** URL |
| `04-live-nlb-generate-save.png` | generate + save working against the API |
| `05-live-nlb-persisted-after-reload.png` | saved names still listed **after a full page reload** - served from the MongoDB StatefulSet on its EBS Persistent Volume |
| `07-grafana-cluster-dashboard.png` | **Grafana + Prometheus** (in-cluster, installed with Helm) - cluster compute dashboard with live data |
| `08-grafana-namegen-namespace-dashboard.png` | per-pod CPU/memory for the `namegen` namespace (mongodb-0 + 2 app replicas) |
| `09-github-actions-oidc-pipeline-green.png` | the **OIDC** CI/CD run green (Status: Success) |
| `10-github-actions-oidc-job-steps.png` | every pipeline step green, including "Configure AWS credentials (OIDC - no static keys)" |

Grafana was accessed with `kubectl port-forward svc/monitoring-grafana 3000:80` (it is ClusterIP on
purpose - the dashboard is never exposed to the internet); the admin password comes from the
`monitoring-grafana` Secret. See [`../monitoring/README.md`](../monitoring/README.md).
