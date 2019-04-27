#!/bin/bash
NAMESPACE="${NAMESPACE:-default}"
kubectl exec -it $1 --namespace $NAMESPACE -- /bin/bash
