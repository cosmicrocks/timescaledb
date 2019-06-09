# timescaledb

[![](https://img.shields.io/docker/cloud/build/cosmicrocks/timescaledb.svg)](https://hub.docker.com/r/cosmicrocks/timescaledb/builds) 

Let’s say you have 2 or more kubernetes clusters in production. I assume you also have few promethues statefulsets running around on some dedicated worker nodes with some taints and affinities. early on you realize that it will be really nice to have all your metrics in one place…


## Deploying our monitoring cluster

There are so many ways these days to get up and running with Kubernetes. Our setup does not assume you are running on a specific cloud provider.


we will start by creating our main cluster on digitalocean
```
### create new cluster and call it cosmic ###
doctl kubernetes cluster create cosmic

### add a secondary node-pool with bigger droplets for timescale ###
doctl kubernetes cluster node-pool create cosmic --name tsdb --count 4 --size s-6vcpu-16gb

### delete the default node-pool ###
doctl kubernetes cluster node-pool delete cosmic cosmic-default-pool

### list node-pools ###
doctl kubernetes cluster node-pool list cosmic

### save kubeonfig ###
doctl kubernetes cluster kubeconfig show cosmic > $HOME/cosmic.config

### check that nodes are running ###
kubectl get nodes
```

## Prometheus operator and kube-prometheus
One of the great things about the Kubernetes architecture that it’s a system composed from independent components decoupled from each other this is very nice of course for the right reasons but it makes the task of properly setting up monitoring and alerting for all of the various cluster components not so easy as you figure out very quickly that these components generate a lot of metrics and that’s even before we started talking about our own services.

This is where prometheus operator and the awesome kube-prometheus projects comes to the rescue saving a lot of time getting up and running with a production ready setup.
```
### (you might need to run this twice if it fails on the first run)  ###
kubectl apply -k https://github.com/cosmicrocks/monitoring.git

### port-forward to grafana ###
kubectl -n monitoring port-forward $(kubectl -n monitoring get pods -l app=grafana -o jsonpath='{.items[*].metadata.name}') 3000:3000 &

and browse to https://127.0.0.1:3000
(username and password are 'admin')
```

## KubeDB
this operator will take care of our databases in production hiding all the necessary extra complexity that comes with replication, backups, snapshots and of course monitoring. I will not advise yet to throw away your managed database holding your critical business data on your favorite cloud provider but for storing metrics and especially when experimenting with new cool stuff I like the flexibility of running my own.
```
### the good guys at kubedb provided us with this easy one liner ###
curl -fsSL https://raw.githubusercontent.com/kubedb/cli/0.12.0/hack/deploy/kubedb.sh | bash

### verify that the setup is successful ###
kubectl get pods --all-namespaces -l app=kubedb
kubectl get crd -l app=kubedb
```


## Timescaledb
this is the fun part here we are telling kubedb to start a postgres cluster with our custom postgres image that is compiled with timescaledb, then we enable timescaledb and pg_prometheus extensions and last step we run the pg-prometheus-adapter
```
### deploy custom timescaledb postgres image ###
kubectl apply -f https://raw.githubusercontent.com/cosmicrocks/timescaledb/master/k8s/timescaledb/postgres-version.yaml

### deploy custom postgres user password ###
kubectl apply -f https://raw.githubusercontent.com/cosmicrocks/timescaledb/master/k8s/timescaledb/timescale-auth.yaml

### deploy timescale postgres kubedb crd ###
kubectl apply -f https://raw.githubusercontent.com/cosmicrocks/timescaledb/master/k8s/timescaledb/timescale.yaml

### deploy pg_admin ###
kubectl apply -f https://raw.githubusercontent.com/cosmicrocks/timescaledb/master/k8s/pgadmin/deployment.yaml

## port-forward to pgadmin ###
kubectl port-forward $(kubectl get pods -l app=pgadmin -o jsonpath='{.items[*].metadata.name}') 8081:80 &

and browse to https://127.0.0.1:8081 
(username and password are 'admin')

### Enable timescaledb and pg_prometheus extensions ###
1) connect to the database using a temp psql pod
kubectl run \
  temp-postgres-client \
  --image launcher.gcr.io/google/postgresql9 \
  --rm --attach --restart=Never \
  -it \
  -- sh -c 'exec psql --host timescaledb --dbname postgres --username postgres --password'

!!! when you are see this message: "If you don't see a command prompt, try pressing enter." 
type the postgres password 'not@secret' and hit enter, this should get you into the postgres=# comand prompt

2) enable extensions
create extension timescaledb;
create extension pg_prometheus;

(hit ctrl+d to exit and delete the pod)

### deploy postgres prometheus adapter ###
kubectl apply -f https://raw.githubusercontent.com/cosmicrocks/timescaledb/master/k8s/pgadapter/deployment.yaml
kubectl apply -f https://raw.githubusercontent.com/cosmicrocks/timescaledb/master/k8s/pgadapter/svc.yaml
```


if all is working you should see now that our prometheus instances on the cluster are writing metrics, you can watch the adapter logs: “kubetail -l app=adapter” also you will see the database connections on the postgres-overview dashboard on grafana at: 127.0.0.1:3000


## What to do next
Once you start sending lots of metrics you will see that it’s necessary to do throw some more magic into the mix.

Network congestion is a thing since all writes going to a single master postgres instance separating the pg adapters and postgres master into different nodes is a good idea this is where pod affinities will come handy.

Storage performance and durability are important when going to production since people are going to rely on that system for observability and alerting, using a storage class with the right type with enough iops for the prostgres setup is a must (I am seeing around 4k iops for 10k row inserts per second.

You can look at my timescaledb repository in the k8s folder for more production ready examples, this file especially: https://github.com/cosmicrocks/timescaledb/blob/master/k8s/timescaledb/timescale-durable.yaml

Conclusion
When trying to figure out what will be the best way to store metrics coming from different clusters running across different regions one will come upon 4 options each one of them with its own upsides and limitations.

Prometheus federation — simple, does not involves more components. Not scalable and does not solve long time storage.

Thanos (without federation) — adds more complexity (sidecar, querier, compactor, store).

Timescaledb — relatively simple and perfomant enough to take you pretty far if you don’t need something like cortex plus the fact that you can query now using sql.

Cortex — highly scalable and actually as you will see later probably the only solution that makes sense when you go beyond a certain scale.

I will update this post with more information soon, please let me know if you need any help with the setup or you find any problems.