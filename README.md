# timescaledb

[![](https://img.shields.io/docker/cloud/build/cosmicrocks/timescaledb.svg)](https://hub.docker.com/r/cosmicrocks/timescaledb/builds) 

Let’s say you have 2 or more kubernetes clusters in production. I assume you also have few promethues statefulsets running around on some dedicated worker nodes with some taints and affinities. early on you realize that it will be really nice to have all your metrics in one place…


## Deploying our monitoring cluster

There are so many ways these days to get up and running with Kubernetes. Our setup does not assume you are running on a specific cloud provider.


we will start by creating our main cluster on digitalocean
<script src="https://gist.github.com/yokiworks/b274eeea4fa347c9feea9eb1899955b2.js"></script>

## Prometheus operator and kube-prometheus
One of the great things about the Kubernetes architecture that it’s a system composed from independent components decoupled from each other this is very nice of course for the right reasons but it makes the task of properly setting up monitoring and alerting for all of the various cluster components not so easy as you figure out very quickly that these components generate a lot of metrics and that’s even before we started talking about our own services.

This is where prometheus operator and the awesome kube-prometheus projects comes to the rescue saving a lot of time getting up and running with a production ready setup.

<script src="https://gist.github.com/yokiworks/7896285091d764e08f6d883fc162cb39.js"></script>


## KubeDB
this operator will take care of our databases in production hiding all the necessary extra complexity that comes with replication, backups, snapshots and of course monitoring. I will not advise yet to throw away your managed database holding your critical business data on your favorite cloud provider but for storing metrics and especially when experimenting with new cool stuff I like the flexibility of running my own.

<script src="https://gist.github.com/yokiworks/a1c52ed81ca96a055961076a4df5c829.js"></script>


## Timescaledb
this is the fun part here we are telling kubedb to start a postgres cluster with our custom postgres image that is compiled with timescaledb, then we enable timescaledb and pg_prometheus extensions and last step we run the pg-prometheus-adapter

<script src="https://gist.github.com/yokiworks/8f4f3a5cea1a14a3838568f96c7fb3f0.js"></script>


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