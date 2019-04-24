#!/bin/bash

NAME=graph-$(head -c 3 /dev/urandom | base64)

helm template chart/ \
   --set namespace=default \
   --set image=neo4j:3.5.2-enterprise \
   --set name=$NAME \
   --set neo4jPassword=mySecretPassword \
   --set authEnabled=true \
   --set coreServers=3 \
   --set readReplicaServers=0 \
   --set cpuRequest=200m \
   --set memoryRequest=1Gi \
   --set volumeSize=2Gi \
   --set acceptLicenseAgreement=yes > expanded.yaml

kubectl apply -f expanded.yaml

echo $NAME
