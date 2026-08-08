# Screenshots

- **01-namegen-app-running.png** — the namegen web app served over HTTP (title "Random Name Generator and Saver").
- **02-namegen-generate-save-working.png** — the full flow: **Get Random Name** → **Save Name** → the name
  persists and appears in "List of Names" ("Laila King: Name has been saved to database") — proving the app ↔
  MongoDB round-trip works.
- **DEPLOY-EVIDENCE.md** — text capture of the live AWS deploy (`kubectl get all -n namegen`, PVC Bound to an
  8 GiB EBS volume, NLB URL, and the live API responses over the NLB).

(The app shots were taken running the exact built image + `mongo:3.6` locally via Docker; the same image the
CI pipeline builds/pushes to ECR and deploys to EKS. Live AWS run is documented in `../DEPLOY-RESULTS.md`.)

## ⬜ Still to capture — the Grafana dashboard (required by the brief)

The brief requires a **monitoring dashboard using Grafana + Prometheus**. The stack is built
(`../monitoring/`) but **not yet screenshotted** — it needs a live cluster.

On the next deploy:

```bash
bash scripts/01-create-cluster.sh       # if not already up
bash scripts/03-build-and-deploy.sh
bash scripts/04-install-monitoring.sh   # Helm: Prometheus + Grafana
bash scripts/05-grafana-portforward.sh  # prints password, forwards :3000
#   ↑ run this on your LAPTOP (Git Bash / WSL) — CloudShell has no browser
```

Then open <http://127.0.0.1:3000> and capture, as `03-grafana-dashboard.png` (and optionally more):

- **Dashboards → General → "Kubernetes / Compute Resources / Cluster"** — the headline shot
- **"Kubernetes / Compute Resources / Namespace (Pods)"** with namespace set to **`namegen`** —
  shows the 3 app pods + the MongoDB StatefulSet under monitoring
- optionally **"Node Exporter / Nodes"** for node CPU/memory/disk

Then `bash scripts/99-destroy.sh` — one cluster spin-up covers the app shots and the Grafana shot.
