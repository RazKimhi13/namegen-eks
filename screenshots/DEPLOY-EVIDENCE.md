# Deploy evidence - namegen on EKS (captured 2026-08-01)

NLB URL: http://k8s-namegen-namegen-1626f74434-9e151fc34920a9a3.elb.us-west-2.amazonaws.com

## kubectl get all -n namegen
```
NAME                           READY   STATUS    RESTARTS   AGE
pod/mongodb-0                  1/1     Running   0          4m43s
pod/namegen-59f99bc4c6-rh7pp   1/1     Running   0          4m8s
pod/namegen-59f99bc4c6-s9bht   1/1     Running   0          4m33s

NAME              TYPE           CLUSTER-IP      EXTERNAL-IP                                                                   PORT(S)        AGE
service/mongodb   ClusterIP      None            <none>                                                                        27017/TCP      4m43s
service/namegen   LoadBalancer   10.100.223.52   k8s-namegen-namegen-1626f74434-9e151fc34920a9a3.elb.us-west-2.amazonaws.com   80:31528/TCP   4m41s

NAME                       READY   AGE
statefulset.apps/mongodb   1/1     4m43s

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/namegen   2/2     2            2           4m42s

NAME                                       STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   VOLUMEATTRIBUTESCLASS   AGE
persistentvolumeclaim/mongo-db-mongodb-0   Bound    pvc-2a338fc6-1dc2-4fa4-8ba8-cd2ba01fb0da   8Gi        RWO            ebs-gp3        <unset>                 4m44s
```

## App verification (over the NLB)
```
GET /            -> HTTP 200  (<title>Random Name Generator and Saver</title>)
GET /api/connection -> {"connectionInfo":{"host":"mongodb","port":27017,"name":"namegen"}}
GET /api/random_name -> {"firstName":"Alexandrea","lastName":"Gerhold"}
GET /api/names   -> [{"_id":"6a6db15ec4d21dd94fc8de9a","created":"2026-08-01T08:42:06.010Z","__v":0,"id":"6a6db15ec4d21dd94fc8de9a"},{"_id":"6a6db15fc4d21dd94fc8de9c","created":"2026-08-01T08:42:07.091Z","__v":0,"id":"6a
```

---

## Second full deploy - 2026-08-12 (OIDC pipeline + monitoring)

Fresh EKS Auto Mode cluster, deployed end-to-end by the **OIDC** workflow (`deploy.yml`,
run [31568870175](https://github.com/RazKimhi13/namegen-eks/actions/runs/31568870175), job `deploy` green in **3m04s**):
checkout -> `sts:AssumeRoleWithWebIdentity` (post-2026-07-15 trust policy with numeric owner/repo IDs,
NO static keys) -> docker build -> push ECR -> `kubectl apply` + `set image` + rollout -> Helm
`kube-prometheus-stack` install. No access keys were used anywhere in this deploy.

| Screenshot | Shows |
|---|---|
| `03-live-nlb-landing.png` | the restyled app served over the internet-facing **NLB** URL |
| `04-live-nlb-generate-save.png` | generate + save round-trips against the API |
| `05-live-nlb-persisted-after-reload.png` | 3 saved names still listed **after a full page reload** - data served from the MongoDB StatefulSet on its EBS PV |
| `07-grafana-cluster-dashboard.png` | **Grafana + Prometheus** (in-cluster, Helm) - cluster compute dashboard with live data, `namegen`/`monitoring` namespaces visible |
| `08-grafana-namegen-namespace-dashboard.png` | per-pod CPU/memory for the `namegen` namespace (mongodb-0 + 2 namegen replicas) |

Grafana was accessed via `kubectl port-forward svc/monitoring-grafana 3000:80` (ClusterIP by design -
the dashboard is never exposed publicly); admin password read from the `monitoring-grafana` Secret.
Cluster destroyed after evidence capture, as always.

| `09-github-actions-oidc-pipeline-green.png` | the OIDC pipeline run green (Status: Success, 3m10s) |
| `10-github-actions-oidc-job-steps.png` | every job step green, incl. "Configure AWS credentials (OIDC - no static keys)" |
