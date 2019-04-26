# Neo4j PKS Integration

For documentation on installation and usage, please refer to the [user guide](user-guide/USER-GUIDE.md)

## Overview

This repo contains the files necessary to package and install Neo4j for Pivotal PKS.  The approach is based on a helm
template, which expands to YAML that can be used to install Neo4j.

In general, the chart is divided into two key components; a StatefulSet for "core nodes" and a StatefulSet for "read replicas".
This structure mimics the [Neo4j Cluster Architecture](https://neo4j.com/docs/operations-manual/current/clustering/introduction/)

Persistent Volumes (PVs) are used to back each cluster pod; HA clusters generally call for a minimum of 3 core nodes and 0 read replicas.

## Related/Ancillary Documentation

* [Considerations for running Neo4j in Orchestration Environments](https://medium.com/neo4j/neo4j-considerations-in-orchestration-environments-584db747dca5)
* [Neo4j PKS User Guide](user-guide/USER-GUIDE.md)
* [Neo4j Clustering Operations Manual](https://neo4j.com/docs/operations-manual/current/clustering/)
* [Detailed technical description of querying Neo4j clusters](https://medium.com/neo4j/querying-neo4j-clusters-7d6fde75b5b4)

## Manual Installation

To avoid the need for helm permissions in the kubernetes cluster, we use helm as a local template
expansion tool, and apply the resulting YAML.

### Helm Expansion

This shows the use of various configuration parameters which can be adjusted.

```
helm template chart/ \
   --set namespace=default \
   --set image=neo4j:3.5.2 \
   --set name=graph-$(head -c 3 /dev/urandom | base64) \
   --set neo4jPassword=mySecretPassword \
   --set authEnabled=true \
   --set coreServers=3 \
   --set readReplicaServers=0 \
   --set cpuRequest=200m \
   --set memoryRequest=1Gi \
   --set volumeSize=2Gi \
   --set volumeStorageClass=standard \
   --set acceptLicenseAgreement=yes > expanded.yaml
```

### Applying to Cluster (Manual)

```kubectl apply -f expanded.yaml```

### Removing the Installation

```kubectl delete -f expanded.yaml```

### (Optional) Removing the Left-Behind PVCs

Here, the value "graph-MdwZ" was the `name` generated in the above step.

```
kubectl delete pvc --namespace default -l release=graph-MdwZ -l app=neo4j
```