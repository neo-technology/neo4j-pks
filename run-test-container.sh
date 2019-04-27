#!/bin/bash

export IMAGE="${1:-gcr.io/neo4j-pivotal/causal-cluster/tester:3.5.4}"
export NAMESPACE="${2:-default}"
export NAME="${3:-testrun}"
export CORES=3
export READ_REPLICAS=1
export HTTP_PORT=7474
export HTTPS_PORT=7473
export BOLT_PORT=7687

env

cat test/tester.yaml | envsubst > target/tester.yaml

# Delete pod if it happens to be leftover from a previous test run.
kubectl delete pod testrun-tester --ignore-not-found=true

# Kick off new test.
kubectl apply -f target/tester.yaml --namespace $NAMESPACE

if [ $? -ne 0 ] ; then
   echo "Failed to run test container"
   exit 1
fi

result=null

while true
do
    result=$(kubectl get pod $NAME-tester --namespace $NAMESPACE --output=json | jq -r '.status.containerStatuses[0].state.terminated.reason')

    if [ "$result" != "null" ] ; then
        break
    else 
        echo "Test container is creating or still running.  Waiting..."
    fi

    sleep 4
done

echo "Dumping logs"
kubectl logs $NAME-tester --namespace $NAMESPACE

echo "=========================================="
echo "FINAL TEST POD STATUS IS $result"
echo "=========================================="

if [ "$result" = "Error" ] ; then
    echo "Tests failed"
    exit 1
fi

if [ "$result" = "Completed" ] ; then
    echo "Tests succeeded, mazel tov\!"
    exit 0
fi

echo "Uncertain test pod result $result"
exit 1