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
