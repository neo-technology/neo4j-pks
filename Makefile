NAME = neo4j
REGISTRY = gcr.io/neo4j-pivotal/causal-cluster
# Solution version
SOLUTION_VERSION=$(shell cat chart/neo4j/Chart.yaml | grep version: | sed 's/.*: //g')
TAG=$(SOLUTION_VERSION)
APP_DEPLOYER_IMAGE=$(REGISTRY)/deployer:$(SOLUTION_VERSION)
APP_RESTORE_IMAGE=$(REGISTRY)/restore:$(SOLUTION_VERSION)
APP_BACKUP_IMAGE=$(REGISTRY)/restore:$(SOLUTION_VERSION)
NEO4J_VERSION=3.5.4-enterprise
TESTER_IMAGE = $(REGISTRY)/tester:$(SOLUTION_VERSION)

APP_NAME ?= testrun

APP_PARAMETERS ?= { \
  "name": "$(APP_NAME)", \
  "namespace": "$(NAMESPACE)", \
  "image": "$(REGISTRY):$(SOLUTION_VERSION)", \
  "coreServers": "3", \
  "readReplicaServers": "1" \
}

APP_TEST_PARAMETERS ?= { }

app/build:: .build/neo4j \
	.build/neo4j/causal-cluster \
	.build/neo4j/helm-package

.build/neo4j: 
	mkdir -p "$@"

.build/neo4j/helm-package:	chart/neo4j/*
	mkdir target
	helm package chart/neo4j --destination target
	ls -l target/neo4j-$(SOLUTION_VERSION).tgz

.build/neo4j/causal-cluster:  causal-cluster/*
	docker pull neo4j:$(NEO4J_VERSION)
	docker build --tag $(REGISTRY):$(SOLUTION_VERSION) \
		--build-arg NEO4J_VERSION="$(NEO4J_VERSION)" \
  	    --build-arg MARKETPLACE_TOOLS_TAG="$(MARKETPLACE_TOOLS_TAG)" \
		-f causal-cluster/Dockerfile \
		.
	docker push $(REGISTRY):$(SOLUTION_VERSION)

