# Architecture

Two views: the **CI/CD pipeline** (how code becomes a running deployment) and the **runtime
infrastructure** (what lives in AWS). The mermaid diagrams below render on GitHub; for the submission,
an editable **draw.io** version lives at [`ARCHITECTURE.drawio`](ARCHITECTURE.drawio).

## 1. CI/CD pipeline (GitHub Actions → ECR → EKS)

```mermaid
flowchart LR
    dev[Developer] -->|git push main| gh[GitHub repo]
    gh -->|triggers workflow| ga[GitHub Actions runner]
    ga -->|OIDC assume-role\nno static keys| iam[AWS IAM Role\nnamegen-github-actions]
    ga -->|docker build .| img[Image :git-sha]
    img -->|docker push| ecr[(Amazon ECR\nrepo: namegen)]
    ga -->|aws eks update-kubeconfig\nkubectl set image| eks[EKS cluster\nnamegen-cluster]
    eks -->|rolling update| pods[namegen pods]
```

Push to `main` → the runner authenticates to AWS via **GitHub OIDC** (assumes the
`namegen-github-actions` role, no long-lived keys) → **builds** the image from the repo root, tags it
with the git SHA, **pushes to ECR** → runs `kubectl set image` → EKS does a **rolling update**.

## 2. Runtime infrastructure (on EKS)

```mermaid
flowchart TB
    user[User on the internet] -->|http :80| nlb[AWS NLB\ninternet-facing]
    subgraph EKS[EKS Auto Mode cluster · namespace: namegen]
        nlb -->|Service type=LoadBalancer| nsvc[Service: namegen]
        nsvc -->|selector app=namegen| ndep[Deployment: namegen\n2 replicas · :8080]
        ndep -->|MONGODB_URL=\nmongodb://genuser:password@mongodb/namegen| msvc[Headless Service: mongodb]
        msvc --> mss[StatefulSet: mongodb\nmongodb-0 · mongo:3.6 · :27017]
        mss -->|volumeClaimTemplates| pvc[(PVC mongo-db-mongodb-0)]
    end
    pvc -->|dynamic provisioning\nebs.csi.eks.amazonaws.com| ebs[(EBS gp3 volume\nencrypted · survives pod delete)]
```

## 3. Monitoring (Grafana + Prometheus, in-cluster)

```mermaid
flowchart TB
    subgraph EKSM[EKS cluster · namespace: monitoring]
        ksm[kube-state-metrics\nK8s object state] --> prom[Prometheus\ncollects + stores]
        nex[node-exporter\nnode CPU/mem/disk] --> prom
        prom -->|datasource| graf[Grafana\ndashboards · ClusterIP]
    end
    appns[namespace: namegen\nnamegen pods + mongodb] -.->|scraped| prom
    graf -->|kubectl port-forward :3000\nNO public LoadBalancer| laptop[Your laptop browser]
```

**Prometheus collects, Grafana visualizes - and both run as pods *inside* the cluster**, which is
why they can read cluster metrics directly. Installed with **Helm** (`kube-prometheus-stack` chart
from ArtifactHub); config in `monitoring/values.yaml`; also installed by a step in the CI/CD workflow.

Grafana is deliberately **ClusterIP, not a LoadBalancer** - a dashboard holding every internal metric
should not be on the public internet. Access is a private `kubectl port-forward` tunnel to `:3000`,
run from a machine that has a browser. Full rationale: [`monitoring/README.md`](monitoring/README.md).

> **CloudWatch vs this:** CloudWatch was built for AWS resources (EC2/EBS/S3), not for Kubernetes
> objects - the Metrics Server add-on only partly bridges it. CloudWatch monitors *the cloud*;
> Prometheus + Grafana monitor *the cluster*.

**Why each piece:**
- **EKS Auto Mode** - AWS runs the control plane + auto-provisions worker nodes, the EBS CSI driver,
  and the AWS Load Balancer controller. Pay $0.10/hr/cluster + nodes + LB.
- **NLB (LoadBalancer Service)** - the brief requires an NLB; the annotations make the Auto Mode LB
  controller provision an internet-facing Network Load Balancer wired to the app pods.
- **Deployment (stateless, 2 replicas)** - the namegen app; rolling updates, zero downtime.
- **StatefulSet + volumeClaimTemplates (stateful)** - MongoDB 3.6 gets a stable identity (`mongodb-0`)
  and its **own EBS volume** that **survives pod deletion** - so saved names persist. A plain
  Deployment would lose them; that's why the DB must be a StatefulSet with a PV.
- **Headless Service `mongodb`** - stable DNS; the app's `MONGODB_URL` host `mongodb` resolves to the pod.
- **Init ConfigMap** - on first boot creates the `genuser`/`password` account on the `namegen` DB so
  the exact `MONGODB_URL` from the brief authenticates.

## Object → requirement map

| Kubernetes object | File | Requirement |
|---|---|---|
| `Namespace namegen` | `k8s/00-namespace.yaml` | isolation |
| `StorageClass ebs-gp3` | `k8s/10-storageclass.yaml` | dynamic EBS provisioning (Auto Mode) |
| `ConfigMap mongodb-init` | `k8s/15-mongodb-init-configmap.yaml` | creates genuser/password on namegen |
| `StatefulSet mongodb` + headless `Service` | `k8s/20-mongodb-statefulset.yaml` | **DB = StatefulSet + Persistent Volumes**, mongodb:3.6 |
| `Deployment namegen` | `k8s/30-namegen-deployment.yaml` | containerized app, `MONGODB_URL`, rolling updates |
| `Service namegen (LoadBalancer)` | `k8s/40-namegen-service.yaml` | **internet exposure via NLB** |
| `ClusterConfig` | `eksctl/cluster.yaml` | **IaC** cluster (Auto Mode) |
| GitHub Actions workflow | `.github/workflows/deploy.yml` | **CI/CD → ECR → EKS** |
| OIDC role + policies | `iam/*.json` | **secure GitHub↔AWS** (no static keys) |
| `kube-prometheus-stack` Helm release (ns `monitoring`) | `monitoring/values.yaml` | **monitoring dashboard with Grafana + Prometheus** |
