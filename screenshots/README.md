# Screenshots

- **01-namegen-app-running.png** — the namegen web app served over HTTP (title "Random Name Generator and Saver").
- **02-namegen-generate-save-working.png** — the full flow: **Get Random Name** → **Save Name** → the name
  persists and appears in "List of Names" ("Laila King: Name has been saved to database") — proving the app ↔
  MongoDB round-trip works.
- **DEPLOY-EVIDENCE.md** — text capture of the live AWS deploy (`kubectl get all -n namegen`, PVC Bound to an
  8 GiB EBS volume, NLB URL, and the live API responses over the NLB).

(The app shots were taken running the exact built image + `mongo:3.6` locally via Docker; the same image the
CI pipeline builds/pushes to ECR and deploys to EKS. Live AWS run is documented in `../DEPLOY-RESULTS.md`.)
