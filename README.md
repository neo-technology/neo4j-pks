### Helm Expansion

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
   --set acceptLicenseAgreement=yes > expanded.yaml
```

### Applying to Cluster (Manual)

```kubectl apply -f expanded.yaml```