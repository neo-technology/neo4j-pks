#!/bin/bash

kubectl delete -f expanded.yaml
kubectl delete pvc --all
