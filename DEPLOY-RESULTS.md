# Live deploy - verified results (2026-08-01)

The full project was deployed end-to-end on the personal AWS account (`313694531036`, `raz-cli`,
region `us-west-2`) and verified working, then torn down. Cost: the cluster ran for ~30 min (control
plane + 2 Auto Mode nodes + 1 NLB + one 8 GiB EBS volume) ≈ a few cents.

## What ran
- **ECR** repo `namegen` created; image `namegen:c2565a4` built from the repo root Dockerfile and pushed.
- **EKS Auto Mode** cluster `namegen-cluster` created via `eksctl create cluster -f eksctl/cluster.yaml`
  (~13 min); 2 worker nodes auto-provisioned (`v1.31.14-eks`).
- **Manifests applied** (`kubectl apply -f k8s/`): namespace, `ebs-gp3` StorageClass, mongodb-init
  ConfigMap, **mongodb:3.6 StatefulSet** + headless Service, **namegen Deployment** (2 replicas), **NLB** Service.

## Verified working
- `mongo-db-mongodb-0` PVC **Bound** to a dynamically-provisioned **8 GiB EBS gp3** volume → the
  StatefulSet + Persistent Volume requirement works.
- All pods `Running` (mongodb-0 + 2 namegen).
- **NLB** provisioned an internet-facing DNS name; app served over it:
  - `GET /` → **HTTP 200**, `<title>Random Name Generator and Saver</title>`
  - `GET /api/connection` → `{"connectionInfo":{"host":"mongodb","port":27017,"name":"namegen"}}`
    → proves the app is bound to the Mongo StatefulSet via the brief's exact `MONGODB_URL`.
  - `GET /api/random_name` → `{"firstName":"Telly","lastName":"Kris"}`
  - `POST /api/names` (Ada Lovelace, Alan Turing) → `{"status":200,"message":"OK"}` ×2
  - `GET /api/names` → returned the persisted records → full DB round-trip works.
  (Raw capture: `screenshots/DEPLOY-EVIDENCE.md`.)

## CI/CD (GitHub Actions)
- Repo `RazKimhi13/namegen-eks` (private), default branch `main`.
- **`deploy-accesskeys.yml` (IAM user access keys - the officially taught path) ran GREEN**
  (run `30692550577`, `build-and-deploy (access keys) → success`): OIDC-free auth → ECR login →
  build → push → update-kubeconfig → apply → set image → rollout, all OK. IAM user `namegen-ci` (the live run's
  name; `scripts/02-setup-iam-user.sh` names it `namegen-github-actions` by default - either works) +
  EKS access entry (`AmazonEKSClusterAdminPolicy`); secrets `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`.
- **`deploy.yml` (OIDC)** initially failed with `Not authorized to perform sts:AssumeRoleWithWebIdentity`.
  Root cause (found later): GitHub changed the OIDC `sub` claim format on **2026-07-15** to include the
  numeric owner/repository IDs, and the trust policy still used the old name-only format. Fixed - see
  `docs/GITHUB-OIDC-ASSUME-ROLE.md` and the second deploy below.

## Second full deploy - 2026-08-12 (OIDC end-to-end)

A fresh cluster was created and this time the entire deploy ran through **`deploy.yml` (OIDC)** with the
corrected trust policy - no static keys anywhere:
- Run `31568870175`, job `deploy` **green in 3m04s**: assume-role (OIDC) → ECR login → build →
  push `namegen:6322a51` → update-kubeconfig → apply + `set image` + rollout → Helm install of
  `kube-prometheus-stack` (Prometheus + Grafana in-cluster).
- App verified over the **NLB** URL: generate + save round-trips, and saved names still listed
  **after a full page reload** (served from the Mongo StatefulSet's EBS volume).
- **Grafana dashboards screenshotted with live data** (cluster + `namegen` namespace) via
  `kubectl port-forward svc/monitoring-grafana 3000:80`.
- Torn down the same hour; verified no leftover cluster / load balancers / EBS volumes.

Screenshots for both deploys: `screenshots/` (see `screenshots/DEPLOY-EVIDENCE.md`).

## Teardown
- `bash scripts/99-destroy.sh` → deleted the k8s resources (released the NLB + EBS), then
  `eksctl delete cluster` (whole CloudFormation stack). Verified no leftover load balancers / EBS
  volumes. ECR repo left in place (costs ~nothing; holds the built image).

## To reproduce
`scripts/00-create-ecr.sh` → `01-create-cluster.sh` → `03-build-and-deploy.sh` → open the NLB URL →
`99-destroy.sh`. For CI: push to `main` (secret + role already exist unless the account was reset).
