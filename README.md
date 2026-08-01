# Random Name Generator on EKS with a GitHub Actions CI/CD Pipeline

Analiza DevSecOps **Final Project** (assignment "Final Project", due **2026-08-20**, 100 pts).

The **namegen** Node.js app (generate a random name, save it, list saved names) deployed to **Amazon
EKS**, with **MongoDB** as a **StatefulSet backed by Persistent Volumes (EBS)**, exposed to the
internet via an **NLB**, and shipped by a **GitHub Actions → ECR → EKS** pipeline. All
Infrastructure-as-Code (`eksctl` Auto Mode) + declarative Kubernetes manifests.

> App source: [redhat-developer-demos/namegen](https://github.com/redhat-developer-demos/namegen)
> (vendored into this repo root, per the brief). Node.js + MongoDB; listens on **8080**; reads **`MONGODB_URL`**.

## Requirements → how each is met (from the assignment brief)

| Brief requirement | How it's met |
|---|---|
| Provision infra with **Terraform or eksctl** (EKS **Auto Mode**) | `eksctl/cluster.yaml` (Auto Mode). *(Terraform is the optional alternative - a `terraform/` module can replace it once the course covers it.)* |
| **CI/CD via GitHub Actions** (auto build + deploy) | `.github/workflows/deploy.yml` (push → build → ECR → `kubectl set image`) |
| Expose via a **Load Balancer (NLB)** | `k8s/40-namegen-service.yaml` (`type: LoadBalancer` + NLB annotations) |
| DB as a **StatefulSet + Persistent Volumes** | `k8s/20-mongodb-statefulset.yaml` (`volumeClaimTemplates` → EBS gp3) |
| Use **mongodb:3.6** | pinned in the StatefulSet |
| App env `MONGODB_URL=mongodb://genuser:password@mongodb/namegen` | set in `k8s/30-namegen-deployment.yaml`; the init ConfigMap creates that user |

## Repo layout (matches the brief's submission checklist)

```
.                              ← app SOURCE + Dockerfile in the root (per brief)
├── server.js, package.json, public/, data/, tests/, ...   ← namegen source (vendored)
├── Dockerfile                 ← builds the app (node:18-alpine, :8080)
├── README.md                  ← this file (project description)
├── ARCHITECTURE.md            ← architecture + CI/CD diagram (draw.io export goes here too)
├── eksctl/                    ← IaC: EKS Auto Mode cluster (or terraform/ if you go that route)
│   └── cluster.yaml
├── k8s/                       ← Kubernetes manifest files (YAML)
│   ├── 00-namespace.yaml
│   ├── 10-storageclass.yaml           ← EBS gp3 (Auto Mode)
│   ├── 15-mongodb-init-configmap.yaml ← creates genuser/password on namegen
│   ├── 20-mongodb-statefulset.yaml    ← mongodb:3.6 StatefulSet + headless Service + PV
│   ├── 30-namegen-deployment.yaml     ← the app (MONGODB_URL, :8080)
│   └── 40-namegen-service.yaml        ← NLB LoadBalancer
├── .github/workflows/deploy.yml   ← CI/CD
├── iam/                       ← GitHub OIDC trust policy + CI permission policy
├── scripts/                   ← 00-create-ecr / 01-create-cluster / 02-setup-github-oidc / 03-build-and-deploy / 99-destroy
└── screenshots/               ← screenshots of the running app (add before submitting)
```

## Prerequisites

- **AWS CLI** on the **personal** account (`--profile personal` = `raz-personal`). MFA + budget alarm already set (29/07).
- **eksctl**, **kubectl**, **docker**, **gh** installed. (Install eksctl via the official *Unix* script.)

> 💸 **Cost discipline:** an EKS cluster bills ~$0.10/hr control plane + EC2 nodes + NLB. **Create →
> work → destroy.** `scripts/99-destroy.sh` tears everything down (k8s first so the NLB + EBS release).

## Run it — manual (fastest end-to-end)

```bash
bash scripts/00-create-ecr.sh          # create the ECR repo
bash scripts/01-create-cluster.sh      # ~15-20 min: EKS Auto Mode cluster
bash scripts/03-build-and-deploy.sh    # build image → push ECR → apply k8s → set image → print NLB URL
# → open the EXTERNAL-IP (NLB DNS) in a browser; generate + save names; they persist in Mongo
bash scripts/99-destroy.sh             # tear it ALL down when done
```

## Run it — the graded CI/CD pipeline (GitHub Actions → ECR → EKS)

1. **Push this repo to GitHub** (the forcing function to use GitHub):
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
5. Grab **screenshots** of the green pipeline + the live app into `screenshots/`, then `scripts/99-destroy.sh`.

## Submission checklist (from the brief)

- [x] Source code in the root + Dockerfile
- [ ] Architecture + CI/CD **diagram (draw.io)** — see `ARCHITECTURE.md` (export the draw.io PNG/`.drawio` here)
- [x] `README.md` describing the project
- [x] Folder with the **Terraform modules / eksctl yaml** (`eksctl/`)
- [x] Folder with the **Kubernetes manifests** (`k8s/`)
- [ ] Folder with **screenshots** of the running app (`screenshots/` — add before submitting)

## Troubleshooting

- **NLB EXTERNAL-IP `<pending>`** — Auto Mode's LB controller takes 2-3 min; re-check `kubectl -n namegen get svc namegen`.
- **Mongo pod Pending** — PVC waiting for an EBS volume; check `kubectl -n namegen get pvc` and that `ebs-gp3` exists.
- **App can't reach Mongo** — the DB service must be named `mongodb` and the user `genuser` must exist (the init ConfigMap creates it on first boot on a fresh volume).
- **CI `sts:AssumeRoleWithWebIdentity` denied** — the trust policy `sub` must match `repo:<org>/<repo>:*`; re-run step 3 with the exact repo name.
