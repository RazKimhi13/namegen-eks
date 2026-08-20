# Monitoring - Grafana + Prometheus

Project requirement: **"Create A Monitoring Dashboard using Grafana+Prometheus."**

## What this is

**Prometheus** scrapes and stores metrics. **Grafana** renders them as dashboards. Both run
**inside the cluster as pods**, which is why they can read cluster metrics directly - nothing
needs to be exported out to AWS.

They are installed with **Helm**, the package manager for Kubernetes. Helm templates are called
**charts** (YAML full of variables) and live on [ArtifactHub](https://artifacthub.io). We use the
official community chart **`prometheus-community/kube-prometheus-stack`**, which bundles:

| Component | Role |
|---|---|
| **Prometheus** | collects + stores metrics (the time-series DB) |
| **Grafana** | visualizes them (the dashboard UI) |
| **kube-state-metrics** | exposes Kubernetes object state (deployments, pods, PVCs…) |
| **node-exporter** | exposes per-node CPU / memory / disk / network |

## Why not CloudWatch?

CloudWatch **was not built for Kubernetes**. It speaks AWS's language - EC2 CPU, EBS, S3, log
groups - and cannot see inside cluster objects. EKS's **Metrics Server** add-on closes only part
of the gap (it exists mainly to feed autoscaling). Rule of thumb: **CloudWatch monitors the cloud;
Prometheus + Grafana monitor the cluster.** Both are used together in practice.

## Install

```bash
./scripts/04-install-monitoring.sh      # helm repo add + upgrade --install, into ns `monitoring`
./scripts/05-grafana-portforward.sh     # prints the admin password, forwards :3000
```

Then open <http://127.0.0.1:3000> (user `admin`, password printed by the script).

> NOTE: **Run the port-forward on a machine with a browser.** The forward terminates on
> `127.0.0.1` of whatever machine runs it. **AWS CloudShell has no GUI**, so forwarding there
> gives you nothing to look at. Use your laptop, in **Git Bash or WSL** - not `cmd.exe`.
>
> This is the organizational pattern too: companies run a dedicated monitoring host (with a
> desktop) that holds the forward, rather than exposing Grafana publicly.

## Why port-forward instead of a LoadBalancer

Grafana's Service is deliberately **ClusterIP**. A monitoring dashboard holding every internal
metric should not sit on the public internet behind an NLB. `kubectl port-forward` gives a
private tunnel that exists only while the command runs.

## Design choices in `values.yaml`

| Choice | Reason |
|---|---|
| `kubeControllerManager` / `kubeScheduler` / `kubeEtcd` / `kubeProxy` **disabled** | On EKS the control plane is **managed by AWS** and these are not scrapeable. Leaving them on produces permanently "down" targets - which looks broken in a screenshot. |
| **No persistence** (Prometheus + Grafana) | A PVC would provision extra **EBS volumes that survive `helm uninstall`** and keep billing - the orphaned-volume trap. This cluster is created and destroyed on demand, so ephemeral metrics are the right trade. |
| `retention: 6h` | Same reasoning - short-lived cluster. |
| Grafana `service.type: ClusterIP` | See above - no public exposure. |
| `adminPassword` **not set** | The chart generates one into a Kubernetes **Secret**. Never commit a password to the repo. |
| `alertmanager: enabled: false` | Not required by the brief; saves resources and keeps teardown clean. |
| `serviceMonitorSelectorNilUsesHelmValues: false` | So Prometheus discovers ServiceMonitors in **all** namespaces, including `namegen`. |

## Dashboards to screenshot

The chart ships a full set of Kubernetes dashboards. Under **Dashboards → General**:

- **Kubernetes / Compute Resources / Cluster** - the best single overview shot
- **Kubernetes / Compute Resources / Namespace (Pods)** - set namespace to `namegen` to show the
  app's 3 pods and the MongoDB StatefulSet
- **Node Exporter / Nodes** - CPU / memory / disk per worker node

Save at least one into [`../screenshots/`](../screenshots/).

## Teardown

`scripts/99-destroy.sh` runs `helm uninstall` before deleting the cluster. With persistence
disabled there are no monitoring PVCs to leak, but the uninstall keeps the teardown ordered and
predictable.

## CI/CD

Both workflows carry an **Install/upgrade monitoring stack** step, gated on the
`INSTALL_MONITORING` env var (default `"true"`). Because `helm upgrade --install` is idempotent,
it is a no-op on runs where nothing changed.

Password retrieval and the port-forward are deliberately **outside** the pipeline - a CI job
should never print a password into its logs.
