# Neo4j PKS Integration

[![CircleCI](https://circleci.com/gh/neo-technology/neo4j-pks.svg?style=svg)](https://circleci.com/gh/neo-technology/neo4j-pks)

For documentation on installation and usage, please refer to the [user guide](user-guide/USER-GUIDE.md)

## Documentation

Official documentation for Neo4j on PKS resides here in Pivotal's repo:

https://github.com/pivotal-cf/docs-neo4j-enterprise

Neo4j maintains a fork of that repo for upstream contributions here:

https://github.com/neo-technology/docs-neo4j-enterprise

The rest of the documentation here focuses on build chain and local testing.

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

### Helm Installation

Just running `make install` should be enough if your `kubectl` is set up properly.  This will additionally
handle the tiller setup, if necessary.

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