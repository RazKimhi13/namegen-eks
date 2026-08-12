# Random Name Generator on EKS with a GitHub Actions CI/CD Pipeline

![Node.js](https://img.shields.io/badge/Node.js-20-339933?logo=nodedotjs&logoColor=white)
![MongoDB](https://img.shields.io/badge/MongoDB-3.6-47A248?logo=mongodb&logoColor=white)
![Docker](https://img.shields.io/badge/Docker-alpine-2496ED?logo=docker&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-EKS%20Auto%20Mode-326CE5?logo=kubernetes&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-IaC-844FBA?logo=terraform&logoColor=white)
![eksctl](https://img.shields.io/badge/eksctl-IaC-FF9900?logo=amazonwebservices&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-OIDC-2088FF?logo=githubactions&logoColor=white)
![Prometheus](https://img.shields.io/badge/Prometheus-metrics-E6522C?logo=prometheus&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana-dashboards-F46800?logo=grafana&logoColor=white)

Final project for the Analiza DevSecOps course.

The **namegen** Node.js app (generate a random name, save it, list saved names) deployed to **Amazon
EKS**, with **MongoDB** as a **StatefulSet backed by Persistent Volumes (EBS)**, exposed to the
internet via an **NLB**, and shipped by a **GitHub Actions → ECR → EKS** pipeline. All
Infrastructure-as-Code (`eksctl` Auto Mode) + declarative Kubernetes manifests.

> App source: [redhat-developer-demos/namegen](https://github.com/redhat-developer-demos/namegen)
> (vendored into this repo root, per the brief). Node.js + MongoDB; listens on **8080**; reads **`MONGODB_URL`**.

## Architecture

**CI/CD pipeline** - push to `main` → GitHub Actions authenticates to AWS via **OIDC** (short-lived
STS credentials, no static keys) → builds the image → pushes to **ECR** → rolls it out on **EKS**:

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

**Runtime** - internet → **NLB** → namegen pods → MongoDB **StatefulSet** on an **EBS** Persistent Volume:

```mermaid
flowchart TB
    user[User on the internet] -->|http :80| nlb[AWS NLB\ninternet-facing]
    subgraph EKS[EKS Auto Mode cluster · namespace: namegen]
        nlb -->|Service type=LoadBalancer| nsvc[Service: namegen]
        nsvc -->|selector app=namegen| ndep[Deployment: namegen\n2 replicas · :8080]
        ndep -->|MONGODB_URL| msvc[Headless Service: mongodb]
        msvc --> mss[StatefulSet: mongodb\nmongodb-0 · mongo:3.6]
        mss -->|volumeClaimTemplates| pvc[(PVC → EBS gp3\nsurvives pod delete)]
    end
```

Full detail (monitoring topology, object→requirement map, design rationale):
[`ARCHITECTURE.md`](ARCHITECTURE.md) · editable draw.io: [`ARCHITECTURE.drawio`](ARCHITECTURE.drawio)

## Requirements → how each is met (from the assignment brief)

| Brief requirement | How it's met |
|---|---|
| Provision infra with **Terraform or eksctl** (EKS **Auto Mode**) | **Both included:** `eksctl/cluster.yaml` (Auto Mode) **and** `terraform/` (Registry VPC + EKS modules, GitHub OIDC role, Access Entries, ECR - see [`terraform/README.md`](terraform/README.md)) |
| **CI/CD via GitHub Actions** (auto build + deploy) | `.github/workflows/deploy.yml` (push → build → ECR → `kubectl set image`) |
| Expose via a **Load Balancer (NLB)** | `k8s/40-namegen-service.yaml` (`type: LoadBalancer` + NLB annotations) |
| DB as a **StatefulSet + Persistent Volumes** | `k8s/20-mongodb-statefulset.yaml` (`volumeClaimTemplates` → EBS gp3) |
| **Monitoring dashboard with Grafana + Prometheus** | `monitoring/values.yaml` + `scripts/04-install-monitoring.sh` - Helm `kube-prometheus-stack` (Prometheus collects, Grafana visualises, both as in-cluster pods); also a step in the CI/CD workflow. Access via `scripts/05-grafana-portforward.sh`. See [`monitoring/README.md`](monitoring/README.md). |
| Use **mongodb:3.6** | pinned in the StatefulSet |
| App env `MONGODB_URL=mongodb://genuser:password@mongodb/namegen` | set in `k8s/30-namegen-deployment.yaml`; the init ConfigMap creates that user |

## Repo layout (matches the brief's submission checklist)

```
.                              ← app SOURCE + Dockerfile in the root (per brief)
├── server.js, package.json, public/, data/, tests/, ...   ← namegen source (vendored)
├── Dockerfile                 ← builds the app (node:20-alpine, non-root, :8080)
├── README.md                  ← this file (project description)
├── ARCHITECTURE.md            ← architecture + CI/CD diagrams (mermaid); ARCHITECTURE.drawio is the editable version
├── eksctl/                    ← IaC option A: EKS Auto Mode cluster (eksctl)
│   └── cluster.yaml
├── terraform/                 ← IaC option B: VPC + EKS Auto Mode + OIDC role + ECR (Registry modules)
├── k8s/                       ← Kubernetes manifest files (YAML)
│   ├── 00-namespace.yaml
│   ├── 10-storageclass.yaml           ← EBS gp3 (Auto Mode)
│   ├── 15-mongodb-init-configmap.yaml ← creates genuser/password on namegen
│   ├── 20-mongodb-statefulset.yaml    ← mongodb:3.6 StatefulSet + headless Service + PV
│   ├── 30-namegen-deployment.yaml     ← the app (MONGODB_URL, :8080)
│   └── 40-namegen-service.yaml        ← NLB LoadBalancer
├── .github/workflows/deploy.yml   ← CI/CD (incl. the monitoring install step)
├── monitoring/                ← Grafana + Prometheus (Helm kube-prometheus-stack)
│   ├── values.yaml                   ← chart values (EKS-tuned, no persistence, ClusterIP)
│   └── README.md                     ← what it is, why not CloudWatch, how to screenshot it
├── iam/                       ← GitHub OIDC trust policy + CI permission policy
├── scripts/                   ← 00-create-ecr / 01-create-cluster / 02-setup-github-oidc /
│                                03-build-and-deploy / 04-install-monitoring /
│                                05-grafana-portforward / 99-destroy
└── screenshots/               ← screenshots of the running app + the Grafana dashboard
```

## Prerequisites

- **AWS CLI** configured (the scripts use `--profile personal`; adjust to your profile).
- **eksctl**, **kubectl**, **docker**, **gh** installed. (Install eksctl via the official *Unix* script.)

> **Cost discipline:** an EKS cluster bills ~$0.10/hr control plane + EC2 nodes + NLB. **Create →
> work → destroy.** `scripts/99-destroy.sh` tears everything down (k8s first so the NLB + EBS release).

## Run it - manual (fastest end-to-end)

```bash
bash scripts/00-create-ecr.sh          # create the ECR repo
bash scripts/01-create-cluster.sh      # ~15-20 min: EKS Auto Mode cluster
bash scripts/03-build-and-deploy.sh    # build image → push ECR → apply k8s → set image → print NLB URL
# → open the EXTERNAL-IP (NLB DNS) in a browser; generate + save names; they persist in Mongo
bash scripts/04-install-monitoring.sh  # Helm: Prometheus + Grafana into the cluster
bash scripts/05-grafana-portforward.sh # prints the admin password, opens Grafana on :3000
bash scripts/99-destroy.sh             # tear it ALL down when done
```

## Run it - Terraform instead of eksctl (IaC option B)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # fill in the numeric GitHub IDs
terraform init && terraform apply              # VPC + EKS + OIDC role + Access Entry + ECR, ~15-20 min
aws eks update-kubeconfig --region us-west-2 --name namegen-cluster
kubectl apply -f ../k8s/
cd .. && bash scripts/04-install-monitoring.sh
# ... work ...
terraform -chdir=terraform destroy             # ALWAYS tear down
```

## Run it - the graded CI/CD pipeline (GitHub Actions → ECR → EKS)

1. **Push this repo to GitHub**:
   ```bash
   gh repo create RazKimhi13/namegen-eks --private --source . --push
   ```
2. `bash scripts/00-create-ecr.sh` and `bash scripts/01-create-cluster.sh` (if not already done).
3. **Wire secure GitHub→AWS auth** (OIDC role, no static keys) + grant it cluster access:
   ```bash
   bash scripts/02-setup-github-oidc.sh RazKimhi13/namegen-eks
   gh secret set AWS_ROLE_ARN -R RazKimhi13/namegen-eks -b "<printed role arn>"
   ```
4. **Push to `main`** → Actions builds the image, pushes to ECR, rolls it out to EKS:
   ```bash
   git commit -am "deploy" && git push && gh run watch -R RazKimhi13/namegen-eks
   ```
5. Grab **screenshots** of the green pipeline + the live app + the Grafana dashboard into
   `screenshots/`, then `scripts/99-destroy.sh`.

## Submission checklist (from the brief)

- [x] Source code in the root + Dockerfile
- [x] Architecture + CI/CD **diagram (draw.io)** - `ARCHITECTURE.drawio` (open/edit at app.diagrams.net) + `ARCHITECTURE.md` (mermaid)
- [x] `README.md` describing the project
- [x] Folder with the **Terraform modules / eksctl yaml** - both: `terraform/` + `eksctl/`
- [x] Folder with the **Kubernetes manifests** (`k8s/`)
- [x] **Monitoring dashboard (Grafana + Prometheus)** - `monitoring/` + install/access scripts + CI step
- [x] Folder with **screenshots** of the running app (`screenshots/`) - app over the NLB, DB persistence, Grafana dashboards with data, green pipeline

## Screenshots

The app served over the NLB, and names persisting across a full reload (read back from the
MongoDB StatefulSet's EBS volume):

| | |
|---|---|
| ![App over the NLB](screenshots/03-live-nlb-landing.png) | ![Persisted after reload](screenshots/05-live-nlb-persisted-after-reload.png) |

The monitoring dashboard (Grafana + Prometheus, in-cluster) and the green OIDC pipeline:

| | |
|---|---|
| ![Grafana cluster dashboard](screenshots/07-grafana-cluster-dashboard.png) | ![Pipeline green](screenshots/09-github-actions-oidc-pipeline-green.png) |

Full set + capture notes: [`screenshots/`](screenshots/README.md) and
[`screenshots/DEPLOY-EVIDENCE.md`](screenshots/DEPLOY-EVIDENCE.md).

Hardening notes + deliberate trade-offs: `HARDENING.md`. Live deploy evidence: `DEPLOY-RESULTS.md` + `screenshots/DEPLOY-EVIDENCE.md`.

## Troubleshooting

- **NLB EXTERNAL-IP `<pending>`** - Auto Mode's LB controller takes 2-3 min; re-check `kubectl -n namegen get svc namegen`.
- **Mongo pod Pending** - PVC waiting for an EBS volume; check `kubectl -n namegen get pvc` and that `ebs-gp3` exists.
- **App can't reach Mongo** - the DB service must be named `mongodb` and the user `genuser` must exist (the init ConfigMap creates it on first boot on a fresh volume).
- **CI `sts:AssumeRoleWithWebIdentity` denied** - since GitHub's **2026-07-15** OIDC change the trust policy `sub` must use the **numeric owner + repo IDs**: `repo:<owner>@<owner_id>/<repo>@<repo_id>:ref:refs/heads/main` with `StringEquals` (AWS's console template is stale). Get the IDs from `https://api.github.com/repos/<owner>/<repo>` (`.owner.id`, `.id`), then re-run `scripts/02-setup-github-oidc.sh` or `terraform apply`.
