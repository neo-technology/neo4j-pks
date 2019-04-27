NAME = neo4j
REGISTRY = gcr.io/neo4j-pivotal/causal-cluster
# Neo4j version, with a BUILD for CI appended, if one is specified; see .circleci/config.yml
CHART_VERSION=$(shell cat chart/neo4j/Chart.yaml | grep version: | sed 's/.*: //g')
SOLUTION_VERSION=$(CHART_VERSION)$(BUILD)
TAG=$(SOLUTION_VERSION)
APP_DEPLOYER_IMAGE=$(REGISTRY)/deployer:$(SOLUTION_VERSION)
APP_RESTORE_IMAGE=$(REGISTRY)/restore:$(SOLUTION_VERSION)
APP_BACKUP_IMAGE=$(REGISTRY)/restore:$(SOLUTION_VERSION)
NEO4J_VERSION=3.5.4-enterprise
TESTER_IMAGE = $(REGISTRY)/tester:$(SOLUTION_VERSION)
NAMESPACE ?= default

APP_NAME ?= testrun

APP_PARAMETERS ?= { \
  "name": "$(APP_NAME)", \
  "namespace": "$(NAMESPACE)", \
  "image": "$(REGISTRY):$(SOLUTION_VERSION)", \
  "coreServers": "3", \
  "readReplicaServers": "1" \
}

APP_TEST_PARAMETERS ?= { }

build:: .build/neo4j/causal-cluster \
  .build/neo4j/tester

package: 	.build/neo4j/helm-package \
	.build/neo4j/docker-package

all:	app/build package

.build/neo4j: 
	mkdir -p "$@"

.build/helm:
	mkdir -p "$@"

.build/tiller-install: .build/helm
	date > .build/helm/tiller
	kubectl apply -f tiller/rbac-config.yaml | tee -a .build/helm/tiller
	helm init --service-account tiller --upgrade | tee -a .build/helm/tiller

uninstall: .build/tiller-install
	helm delete --purge $(APP_NAME) || true
	kubectl delete pvc --namespace $(NAMESPACE) -l release=$(APP_NAME)

install: .build/tiller-install uninstall
	helm install chart/neo4j --namespace $(NAMESPACE) --name $(APP_NAME) \
		--set namespace=$(NAMESPACE) \
		--set image=$(REGISTRY):$(SOLUTION_VERSION) \
		--set name=$(APP_NAME) \
		--set neo4jPassword=mySecretPassword \
		--set authEnabled=true \
		--set coreServers=3 \
		--set readReplicaServers=1 \
		--set cpuRequest=200m \
		--set memoryRequest=1Gi \
		--set volumeSize=2Gi \
		--set volumeStorageClass=standard \
		--set acceptLicenseAgreement=yes
	echo $(APP_NAME) > .build/helm/installed

.build/neo4j/docker-package: .build/neo4j/causal-cluster
	docker save $(REGISTRY):$(SOLUTION_VERSION) | gzip -9 > target/causal-cluster_image.$(SOLUTION_VERSION).tgz
	docker save $(TESTER_IMAGE) | gzip -9 > target/tester_image.$(SOLUTION_VERSION).tgz

.build/neo4j/helm-package: chart/neo4j/*
	mkdir -p target	
	helm package chart/neo4j --destination target
	ls -l target/neo4j-$(CHART_VERSION).tgz

.build/neo4j/causal-cluster:  .build/neo4j causal-cluster/*
	docker pull neo4j:$(NEO4J_VERSION)
	docker build --tag $(REGISTRY):$(SOLUTION_VERSION) \
		--build-arg NEO4J_VERSION="$(NEO4J_VERSION)" \
		-f causal-cluster/Dockerfile \
		.
	docker push $(REGISTRY):$(SOLUTION_VERSION)

.build/neo4j/tester: .build/neo4j test/*.yaml test/*.sh
	$(call print_target,$@)
	cd test && docker build \
	   --tag "$(TESTER_IMAGE)" \
	   -f Dockerfile \
	   .
	docker push "$(TESTER_IMAGE)"
	@touch "$@"
