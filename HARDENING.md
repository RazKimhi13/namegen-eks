# Hardening notes + deliberate trade-offs

A full QA (4 review passes) ran on this repo. It deploys green and meets every brief requirement.
This file records what was hardened and the trade-offs kept **on purpose** (mostly brief- or rubric-dictated).

## Applied
- **Dockerfile:** `node:20-alpine` (was EOL 18), non-root `USER node`, `npm ci` only (dropped the `|| npm install` fallback), `.dockerignore` so the build context can't bake in `.env`/junk.
- **k8s namegen Deployment:** resource requests/limits, `imagePullPolicy: IfNotPresent`, a non-root `securityContext` (`runAsNonRoot`, `runAsUser 1000`, `allowPrivilegeEscalation:false`, drop ALL caps, seccomp RuntimeDefault), and an **initContainer that waits for `mongodb:27017`** (no more CrashLoop-until-DB-up).
- **k8s Mongo StatefulSet:** resource requests/limits + `allowPrivilegeEscalation:false`.
- **StorageClass:** dropped the `is-default-class` annotation (the StatefulSet names `ebs-gp3` explicitly; avoids a dual-default-class warning under Auto Mode).
- **CI OIDC trust:** `sub` scoped to `repo:<org>/<repo>:ref:refs/heads/main` (was any-ref `:*`).
- **.gitignore:** `*.pem`, `*.key`, `kubeconfig*`, `.aws/`. The instructor's reference solution is git-ignored (not submitted).

## Deliberate trade-offs (kept as-is)
1. **DB credentials are inline in the Deployment env** (`MONGODB_URL=mongodb://genuser:password@mongodb/namegen`).
   The brief dictates this exact string. Best practice = a `Secret` referenced via `valueFrom.secretKeyRef`
   (same value, better hygiene) - left inline so it matches the assignment literally.
2. **Mongo init-user provisioning runs ONCE on a fresh volume** (the ConfigMap `createUser` runs via
   `/docker-entrypoint-initdb.d` only when `/data/db` is empty). On a **reused PVC** it won't re-run, so if you
   change the user you must wipe the PVC. Fine for the intended **create→work→destroy** workflow (each cluster
   gets a fresh EBS volume). A fully robust design would enable real `--auth` (root user from a Secret) or an
   idempotent init Job.
3. **Credentialed URI against an auth-disabled Mongo.** mongo:3.6 runs without `--auth` here; the app still
   authenticates because `genuser` exists. Real auth (`--auth` + root Secret) + a NetworkPolicy on 27017 would
   harden it, but the brief's string works as-is and the DB is cluster-internal (headless, no ingress).
4. **Mongo container is NOT forced `runAsNonRoot`.** The official mongo image + EBS volume ownership (`fsGroup`)
   make non-root fiddly; kept the image default to protect the proven-green DB. The app pod IS non-root.
5. **CI principal gets `AmazonEKSClusterAdminPolicy`** (EKS access entry). This is exactly what the official
   course **"DevOps - Step by Step"** instructs, so it's kept for the rubric. Least-privilege alternative:
   pre-create the Namespace + StorageClass at cluster-provision time, then grant the CI identity
   `AmazonEKSEditPolicy` scoped `type=namespace,namespaces=namegen` (the CI only `apply`s namespaced objects then).
6. **eksctl, not Terraform.** The brief allows either; eksctl (Auto Mode) is used. A `terraform/` module is the
   natural next addition once the course covers Terraform.
