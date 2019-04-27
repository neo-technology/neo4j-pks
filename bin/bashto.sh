#!/bin/bash
NAMESPACE="${NAMESPACE:-default}"
kubectl exec -it $1-neo4j-core-0 --namespace $NAMESPACE -- /bin/bash
