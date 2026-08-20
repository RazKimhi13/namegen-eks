# Random Name Generator on EKS

![Kubernetes](https://img.shields.io/badge/Amazon%20EKS-Auto%20Mode-326CE5?logo=kubernetes&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-eksctl-844FBA?logo=terraform&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-OIDC-2088FF?logo=githubactions&logoColor=white)
![MongoDB](https://img.shields.io/badge/MongoDB-3.6-47A248?logo=mongodb&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana%20+%20Prometheus-monitoring-F46800?logo=grafana&logoColor=white)

A small Node.js app (generate a random name, save it, list what you saved) running on Amazon EKS,
with MongoDB as a StatefulSet on an EBS volume, reachable from the internet through a Network Load
Balancer, and shipped by a GitHub Actions pipeline that builds the image, pushes it to ECR and rolls
it out to the cluster.

This is my final project for the Analiza DevSecOps course (cohort A599, August 2026). The app itself
is deliberately trivial - the point of the exercise is everything around it: infrastructure as code,
a stateful workload that keeps its data, a real deployment pipeline with no long-lived AWS keys, and
monitoring you can actually look at.

The app comes from [redhat-developer-demos/namegen](https://github.com/redhat-developer-demos/namegen)
and is vendored into the repository root. It listens on port 8080 and reads its database connection
string from `MONGODB_URL`.

## Architecture

Pushing to `main` is the only thing that deploys. The runner authenticates to AWS with OIDC, so
there are no access keys stored in GitHub:

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

At runtime, traffic comes in through the NLB and the app talks to MongoDB over cluster DNS. The
database keeps its data on its own EBS volume, so deleting the pod does not lose the saved names:

```mermaid
flowchart TB
    user[User on the internet] -->|http :80| nlb[AWS NLB\ninternet-facing]
    subgraph EKS[EKS Auto Mode cluster - namespace namegen]
        nlb -->|Service type=LoadBalancer| nsvc[Service: namegen]
        nsvc -->|selector app=namegen| ndep[Deployment: namegen\n2 replicas - :8080]
        ndep -->|MONGODB_URL| msvc[Headless Service: mongodb]
        msvc --> mss[StatefulSet: mongodb\nmongodb-0 - mongo:3.6]
        mss -->|volumeClaimTemplates| pvc[(PVC to EBS gp3\nsurvives pod delete)]
    end
```

The monitoring topology, the reasoning behind each object, and an editable draw.io version are in
[`ARCHITECTURE.md`](ARCHITECTURE.md) and [`ARCHITECTURE.drawio`](ARCHITECTURE.drawio).

## The stack

| Layer | What I used |
|---|---|
| Cluster | Amazon EKS in Auto Mode, provisioned two ways: [`eksctl/cluster.yaml`](eksctl/cluster.yaml) or [`terraform/`](terraform/README.md) |
| App | Node.js 20 on Alpine, non-root, built from the Dockerfile in the repo root |
| Database | MongoDB 3.6 as a StatefulSet with `volumeClaimTemplates`, dynamically provisioned EBS gp3 |
| Ingress | Service of type LoadBalancer with the NLB annotations, internet-facing, targeting pod IPs |
| Registry | Amazon ECR, images tagged with the git SHA |
| Pipeline | GitHub Actions, AWS auth over OIDC and STS ([`deploy.yml`](.github/workflows/deploy.yml)) |
| Monitoring | `kube-prometheus-stack` via Helm: Prometheus scrapes, Grafana draws, both in-cluster |

## What the pipeline does

Every push to `main` runs [`.github/workflows/deploy.yml`](.github/workflows/deploy.yml):

1. Assumes the `namegen-github-actions` IAM role through GitHub's OIDC provider and gets short-lived
   STS credentials. Nothing permanent is stored in the repository secrets except the role ARN.
2. Logs in to ECR, builds the image from the repository root and pushes it tagged with the commit
   SHA, so every deployment is traceable to one commit.
3. Writes a kubeconfig for the cluster (`aws eks update-kubeconfig`), which works because there is an
   EKS access entry pointing at that same role.
4. Applies `k8s/` and runs `kubectl set image` so the Deployment does a rolling update, then waits on
   `kubectl rollout status` and fails the run if it does not converge in three minutes.
5. Installs or upgrades the Prometheus and Grafana release with Helm. It uses `helm upgrade
   --install`, so re-running the pipeline is a no-op rather than a reinstall. Fetching the Grafana
   password and port-forwarding stay out of CI on purpose, since a pipeline should not print a
   password into its log.

There is a second workflow, [`deploy-accesskeys.yml`](.github/workflows/deploy-accesskeys.yml), which
does the same thing with an IAM user and access keys. That is the version the course taught first and
I kept it for comparison, but it only runs on manual dispatch. OIDC is the one that runs on push.

## Repository layout

```
.
├── server.js, package.json, public/, data/, tests/   the app (vendored)
├── Dockerfile                       node:20-alpine, non-root, port 8080
├── eksctl/cluster.yaml              cluster as code, option A
├── terraform/                       cluster as code, option B (VPC + EKS + OIDC role + ECR)
├── k8s/
│   ├── 00-namespace.yaml
│   ├── 10-storageclass.yaml         EBS gp3 for Auto Mode
│   ├── 15-mongodb-init-configmap.yaml   creates the genuser account on first boot
│   ├── 20-mongodb-statefulset.yaml  mongo:3.6, headless Service, EBS volume claim
│   ├── 30-namegen-deployment.yaml   the app, 2 replicas
│   └── 40-namegen-service.yaml      internet-facing NLB
├── .github/workflows/               deploy.yml (OIDC) and deploy-accesskeys.yml
├── monitoring/                      Helm values for kube-prometheus-stack
├── iam/                             OIDC trust policy and the CI permission policy
├── scripts/                         create ECR, create cluster, wire auth, deploy, destroy
└── screenshots/                     the app and the dashboards, running
```

## Running it yourself

You need the AWS CLI configured, plus `eksctl`, `kubectl`, `docker` and `gh`. The scripts use
`--profile personal` and region `us-west-2`; change those at the top of each script if yours differ.

A cluster is not free: roughly $0.10/hour for the control plane, plus nodes, plus the load balancer.
Create it, do the work, then destroy it. `scripts/99-destroy.sh` deletes the Kubernetes objects first
so the NLB and the EBS volume are released before the cluster goes away.

```bash
bash scripts/00-create-ecr.sh           # ECR repository
bash scripts/01-create-cluster.sh       # EKS Auto Mode cluster, 15-20 minutes
bash scripts/03-build-and-deploy.sh     # build, push, apply, print the NLB URL
bash scripts/04-install-monitoring.sh   # Prometheus + Grafana via Helm
bash scripts/05-grafana-portforward.sh  # prints the admin password, opens Grafana on :3000
bash scripts/99-destroy.sh              # tear it all down
```

Terraform instead of eksctl:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # fill in the numeric GitHub owner and repo IDs
terraform init && terraform apply              # VPC, EKS, OIDC role, access entry, ECR
aws eks update-kubeconfig --region us-west-2 --name namegen-cluster
kubectl apply -f ../k8s/
terraform destroy                              # when you are done
```

To run the pipeline rather than deploying by hand, create the cluster and the ECR repository as
above, then wire the GitHub side once:

```bash
bash scripts/02-setup-github-oidc.sh RazKimhi13/namegen-eks
gh secret set AWS_ROLE_ARN -R RazKimhi13/namegen-eks -b "<the role ARN it prints>"
git commit -am "deploy" && git push        # Actions takes it from here
```

## Screenshots

The app over the NLB, and the saved names still there after a full page reload, which means they came
back from the EBS volume behind the StatefulSet:

| | |
|---|---|
| ![App over the NLB](screenshots/03-live-nlb-landing.png) | ![Persisted after reload](screenshots/05-live-nlb-persisted-after-reload.png) |

Grafana with live cluster data, and the pipeline run that deployed it:

| | |
|---|---|
| ![Grafana cluster dashboard](screenshots/07-grafana-cluster-dashboard.png) | ![Pipeline green](screenshots/09-github-actions-oidc-pipeline-green.png) |

The full set, with the commands used to capture each one, is in
[`screenshots/`](screenshots/README.md). What the deploys actually did, including the API round-trips
against MongoDB, is written up in [`DEPLOY-RESULTS.md`](DEPLOY-RESULTS.md).

## Notes from building it

Three things cost me real time and are worth writing down.

**GitHub changed its OIDC subject format on 15 July 2026.** My first OIDC run failed with
`Not authorized to perform sts:AssumeRoleWithWebIdentity` even though the trust policy looked right,
and the template AWS generates in the console is still the old format. The `sub` condition now needs
the numeric owner and repository IDs, matched with `StringEquals`:

```
repo:<owner>@<owner_id>/<repo>@<repo_id>:ref:refs/heads/main
```

Both IDs come from `https://api.github.com/repos/<owner>/<repo>` (`.owner.id` and `.id`).
[`docs/GITHUB-OIDC-ASSUME-ROLE.md`](docs/GITHUB-OIDC-ASSUME-ROLE.md) has the full policy.

**The load balancer annotation values are exact.** `aws-load-balancer-scheme` has to be
`internet-facing`; `external` is deprecated and silently gets you Kubernetes' default internal load
balancer with no public address, which looks like a broken cluster rather than a typo.
`aws-load-balancer-nlb-target-type: ip` sends traffic to the pods instead of the nodes.

**The database Service name is part of the app's configuration.** `MONGODB_URL` points at the host
`mongodb`, so the headless Service has to be called exactly that. Rename one and the app crash-loops
with a DNS error that reads like a network problem.

Design decisions I made on purpose, including the ones where the assignment's requirements and
security best practice pull in different directions, are listed in [`HARDENING.md`](HARDENING.md).

## How it maps to the assignment

| Requirement | Where |
|---|---|
| Provision the cluster with Terraform or eksctl, EKS Auto Mode | both: `eksctl/cluster.yaml` and `terraform/` |
| CI/CD with GitHub Actions | `.github/workflows/deploy.yml` |
| Expose the app through an NLB | `k8s/40-namegen-service.yaml` |
| Database as a StatefulSet with Persistent Volumes | `k8s/20-mongodb-statefulset.yaml` |
| Monitoring dashboard with Grafana and Prometheus | `monitoring/`, plus a step in the workflow |
| MongoDB 3.6 | pinned in the StatefulSet |
| `MONGODB_URL=mongodb://genuser:password@mongodb/namegen` | `k8s/30-namegen-deployment.yaml`, with the init ConfigMap creating that user |
| Diagram, README, manifests folder, screenshots | this file, `ARCHITECTURE.drawio`, `k8s/`, `screenshots/` |

## Troubleshooting

- **The NLB address stays `<pending>`.** Auto Mode's load balancer controller takes two or three
  minutes. Re-check with `kubectl -n namegen get svc namegen`.
- **The Mongo pod sits in `Pending`.** Its claim is waiting for a volume. Check
  `kubectl -n namegen get pvc` and that the `ebs-gp3` StorageClass exists.
- **The app cannot reach Mongo.** The Service has to be named `mongodb` and `genuser` has to exist.
  The init ConfigMap only creates that user on a fresh volume, so a reused PVC keeps the old one.
- **`sts:AssumeRoleWithWebIdentity` is denied.** The trust policy is in the pre-15-July format. See
  the note above.
