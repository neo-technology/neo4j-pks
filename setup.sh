#!/bin/bash

NAME=graph-$(head -c 3 /dev/urandom | base64)

helm template chart/ \
   --set namespace=default \
   --set image=mdavidallen/causal-cluster:3.5 \
   --set name=$NAME \
   --set neo4jPassword=mySecretPassword \
   --set authEnabled=true \
   --set coreServers=3 \
   --set readReplicaServers=0 \
   --set cpuRequest=200m \
   --set memoryRequest=1Gi \
   --set volumeSize=2Gi \
   --set volumeStorageClass=standard \
   --set acceptLicenseAgreement=yes > expanded.yaml

kubectl apply -f expanded.yaml

echo $NAME
