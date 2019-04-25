# External Exposure of Neo4j Clusters

As described in the user guide, by default when you use the approach in this repo, each
node in your cluster gets a private internal DNS address, which it advertises to its clients.

This works "out of the box" without any knowledge of your local addressing or DNS situation.  The
downside is that external clients cannot use the bolt+routing protocol to connect to the cluster,
because they cannot route traffic to strictly cluster internal DNS names.

To address this, we need two things:

1. An externally valid DNS name or IP address that clients can connect to, that routes traffic to the kubernetes pod
2. The `dbms.connector.default_advertised_address` setting for each Neo4j node set to that address.

As background on these topics, I'd recommend this article:
[Kubernetes NodePort vs. LoadBalancer vs. Ingress?  When should I use what?](https://medium.com/google-cloud/kubernetes-nodeport-vs-loadbalancer-vs-ingress-when-should-i-use-what-922f010849e0)

## Option 1: NodePort and Port Spreading

You may choose to have an externally accessible IP for your kubernetes cluster, and then "port spread" the cluster's machines.  

In the node's statefulset resource for example, you can use code like this in the "command" section
that starts the container.

```
namespace=my-neo4j-namespace
publicip=1.2.3.4

if [ $(hostname -f) == "neo4j-core-0.neo4j.$namespace.svc.cluster.local" ]; then export "NEO4J_dbms_connector_bolt_advertised__address"=$publicip:30149; fi
if [ $(hostname -f) == "neo4j-core-1.neo4j.$namespace.svc.cluster.local" ]; then export "NEO4J_dbms_connector_bolt_advertised__address"=$publicip:31932; fi
if [ $(hostname -f) == "neo4j-core-2.neo4j.$namespace.svc.cluster.local" ]; then export "NEO4J_dbms_connector_bolt_advertised__address"=$publicip:32497; fi
```

This will configure the Neo4j nodes to expose each node on a different port of the same 
public IP (port spreading).

We can then create three different `NodePort` services like this:

```
apiVersion: v1
kind: Service
metadata:
  labels:
    app: neo4j
    component: core
  name: neo4j-bolt-core-0
  namespace: my-neo4j-namespace
spec:
  ports:
    - name: bolt
      port: 7687
      protocol: TCP
  selector:
    app: neo4j
    statefulset.kubernetes.io/pod-name: "neo4j-core-0"
  sessionAffinity: None
  type: NodePort
status:
  loadBalancer: {}
```

