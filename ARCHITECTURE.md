# Architecture

Two views: the **CI/CD pipeline** (how code becomes a running deployment) and the **runtime
infrastructure** (what lives in AWS). The mermaid diagrams below render on GitHub; for the submission,
also export a **draw.io** version of these (`architecture.drawio` + a PNG) into this folder.

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

**Why each piece:**
- **EKS Auto Mode** — AWS runs the control plane + auto-provisions worker nodes, the EBS CSI driver,
  and the AWS Load Balancer controller. Pay $0.10/hr/cluster + nodes + LB.
- **NLB (LoadBalancer Service)** — the brief requires an NLB; the annotations make the Auto Mode LB
  controller provision an internet-facing Network Load Balancer wired to the app pods.
- **Deployment (stateless, 2 replicas)** — the namegen app; rolling updates, zero downtime.
- **StatefulSet + volumeClaimTemplates (stateful)** — MongoDB 3.6 gets a stable identity (`mongodb-0`)
  and its **own EBS volume** that **survives pod deletion** - so saved names persist. A plain
  Deployment would lose them; that's why the DB must be a StatefulSet with a PV.
- **Headless Service `mongodb`** — stable DNS; the app's `MONGODB_URL` host `mongodb` resolves to the pod.
- **Init ConfigMap** — on first boot creates the `genuser`/`password` account on the `namegen` DB so
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
