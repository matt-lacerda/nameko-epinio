HOST ?= localhost
NAMESPACE ?= nameko
CONTEXT ?= kind-$(NAMESPACE)
TAG ?= dev
LOCAL_DNS ?= 127.0.0.1.sslip.io
SERVICE_DEPENDENCIES := postgresql redis rabbitmq
IMAGES := orders products gateway

# epinio
deploy-epinio: kind-create-cluster kind-setup-ingress kind-setup-cert-manager
	helm repo add epinio https://epinio.github.io/helm-charts
	helm install epinio -n epinio --create-namespace epinio/epinio --set global.domain=$(LOCAL_DNS)
	epinio login -u admin https://epinio.$(LOCAL_DNS)
	$(MAKE) push-epinio-nameko-images

kind-setup-cert-manager:
	kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.yaml
	sleep 20
	kubectl wait --namespace cert-manager \
    --for=condition=available deployment/cert-manager \
    --timeout=300s

create-epinio-service-dependencies:
	for service_name in $(SERVICE_DEPENDENCIES); do epinio service create $$service_name-dev $(NAMESPACE)-$$service_name; done
	$(MAKE) bind-epinio-services

push-epinio-nameko-images: load-nameko-docker-images
	for image in $(IMAGES); do epinio push -n $$image --container-image-url $(NAMESPACE)/nameko-example-$$image:$(TAG) --chart-value appListeningPort=8000; done
	$(MAKE) create-epinio-service-dependencies
	
load-nameko-docker-images:
	cd ..; $(MAKE) build
	kind load docker-image $(NAMESPACE)/nameko-example-gateway:$(TAG) --name $(NAMESPACE)
	kind load docker-image $(NAMESPACE)/nameko-example-orders:$(TAG) --name $(NAMESPACE)
	kind load docker-image $(NAMESPACE)/nameko-example-products:$(TAG) --name $(NAMESPACE)

bind-epinio-services:
	for image in $(IMAGES); do \
		for service in $(SERVICE_DEPENDENCIES); do \
			epinio service bind nameko-$$service $$image; \
		done; \
	done
	$(MAKE) epinio-set-app-variables

epinio-set-app-variables:
	$(MAKE) epinio-bind-rabbitmq-vars
	$(MAKE) epinio-bind-redis-vars
	$(MAKE) epinio-bind-postgres-vars

epinio-bind-rabbitmq-vars:
	for app in $(IMAGES); do \
		epinio app env set $$app RABBIT_PASSWORD \
			$$(kubectl get secret $$(kubectl get secrets -n workspace -o jsonpath='{range .items[?(@.data.rabbitmq-password)]}{.metadata.name}{"\n"}{end}' | grep rabbitmq) -n workspace -o jsonpath='{.data.rabbitmq-password}' | base64 --decode); \
		epinio app env set $$app RABBIT_HOST $$(kubectl get svc -n workspace | grep rabbit | grep -v headless | awk '{print $$1}').workspace.svc.cluster.local; \
		epinio app env set $$app RABBIT_PORT 5672; \
		epinio app env set $$app RABBIT_USER user; \
		epinio app env set $$app RABBIT_MANAGEMENT_PORT 15672; \
	done

epinio-bind-redis-vars:
	epinio app env set products REDIS_PASSWORD \
		$$(kubectl get secret $$(kubectl get secrets -n workspace -o jsonpath='{range .items[?(@.data.redis-password)]}{.metadata.name}{"\n"}{end}' | grep redis) -n workspace -o jsonpath='{.data.redis-password}' | base64 --decode); \
	epinio app env set products REDIS_HOST \
		$$(kubectl get svc -n workspace | grep redis-master | awk '{print $$1}').workspace.svc.cluster.local; \
	epinio app env set products REDIS_PORT 6379
	epinio app env set products REDIS_INDEX 11

epinio-bind-postgres-vars:
	epinio app env set orders DB_HOST \
		$$(kubectl get svc -n workspace | grep postgres | grep -v postgresql-hl | awk '{print $$1}').workspace.svc.cluster.local; \
	epinio app env set orders DB_PASSWORD $() \
		$$(kubectl get secret $$(kubectl get secrets -n workspace -o jsonpath='{range .items[?(@.data.postgres-password)]}{.metadata.name}{"\n"}{end}' | grep postgres) -n workspace -o jsonpath='{.data.postgres-password}' | base64 --decode); \
	epinio app env set orders DB_USER postgres
	epinio app env set orders DB_NAME postgres

check-epinio-logs:
	kubectl -n epinio get events --sort-by='{.lastTimestamp}'

# test epinio
epinio-smoke-test:
	../test/nex-smoketest.sh https://gateway.$(LOCAL_DNS)

epinio-perf-test:
	cd ..; ./test/nex-bzt.sh https://gateway.$(LOCAL_DNS)

# all in one
kind-create-cluster:
	kind create cluster --config kind-config.yaml --name $(NAMESPACE)
	kind export kubeconfig --name $(NAMESPACE)
	NEWURL=$$(kubectl config view | grep -B1 'name: $(CONTEXT)' | grep server: | awk '{print $$2}' | sed -e 's/0.0.0.0/$(HOST)/') ; \
		kubectl config set-cluster $(CONTEXT) --server=$${NEWURL} --insecure-skip-tls-verify=true 

# src: https://kind.sigs.k8s.io/docs/user/ingress/

kind-setup-ingress:
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml

#STEPCONF - Increase the time and wait for the ingress creation to be completed
	sleep 30
	kubectl wait --namespace ingress-nginx \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=90s

undeployK8:
	# $(MAKE) delete-namespace
	kind delete cluster --name $(NAMESPACE)

deployK8: kind-create-cluster kind-setup-ingress
#STEPCONF - uncomment this line to install the stable repo for helm
	$(MAKE) init-helm
	$(MAKE) create-namespace
	$(MAKE) deploy-dependencies
	$(MAKE) install-charts

# test
smoke-test:
	../test/nex-smoketest.sh http://localhost

perf-test:
	cd ..; ./test/nex-bzt.sh http://localhost

# kubectl short-cuts
get-nodes:
	kubectl --context=$(CONTEXT) --namespace $(NAMESPACE) get nodes

get-services:
	kubectl --context=$(CONTEXT) --namespace $(NAMESPACE) get services -o wide

get-pods:
	kubectl --context=$(CONTEXT) --namespace $(NAMESPACE) get pods -o wide

watch-svcs-pods:
	watch -n 0 \
	'kubectl --context=$(CONTEXT) --namespace $(NAMESPACE) get services -o wide; echo "---"; \
	 kubectl --context=$(CONTEXT) --namespace $(NAMESPACE) get pods -o wide'

get-logs:
	kubectl get pods --context=$(CONTEXT) --namespace $(NAMESPACE) --no-headers=true | awk '{print $$1}' | grep $(name) | xargs kubectl --context=$(CONTEXT) --namespace $(NAMESPACE) logs -f

describe-pod:
	kubectl get pods --context=$(CONTEXT) --namespace $(NAMESPACE) --no-headers=true | awk '{print $$1}' | grep $(name) | xargs kubectl --context=$(CONTEXT) --namespace $(NAMESPACE) describe pod

describe-svc:
	kubectl get services --context=$(CONTEXT) --namespace $(NAMESPACE) --no-headers=true | awk '{print $$1}' | grep $(name) | xargs kubectl --context=$(CONTEXT) --namespace $(NAMESPACE) describe service

create-namespace:
	kubectl --context=$(CONTEXT) apply -f namespace.yaml

delete-namespace:
	kubectl --context=$(CONTEXT) delete -f namespace.yaml

# helm
init-helm:
	helm repo add stable https://charts.helm.sh/stable
	helm repo update

list-charts:
	helm --kube-context=$(CONTEXT) list --namespace=$(NAMESPACE)

deploy-dependencies:
	helm upgrade broker stable/rabbitmq --install \
		--namespace $(NAMESPACE) --kube-context=$(CONTEXT)
	helm upgrade db stable/postgresql --install \
		--set postgresqlDatabase=orders \
		--namespace $(NAMESPACE) --kube-context=$(CONTEXT)
	helm upgrade cache stable/redis --install \
		--namespace $(NAMESPACE) --kube-context=$(CONTEXT)
	kubectl --context=$(CONTEXT) --namespace=$(NAMESPACE) get pods

install-charts:
	cd ..; $(MAKE) build
	kind load docker-image $(NAMESPACE)/nameko-example-gateway:$(TAG) --name $(NAMESPACE)
	kind load docker-image $(NAMESPACE)/nameko-example-orders:$(TAG) --name $(NAMESPACE)
	kind load docker-image $(NAMESPACE)/nameko-example-products:$(TAG) --name $(NAMESPACE)
	$(MAKE) SERVICE_NAME=gateway install-chart
	$(MAKE) SERVICE_NAME=orders install-chart
	$(MAKE) SERVICE_NAME=products install-chart

test-charts:
	$(MAKE) SERVICE_NAME=gateway test-chart
	$(MAKE) SERVICE_NAME=orders test-chart
	$(MAKE) SERVICE_NAME=products test-chart

lint-charts:
	$(MAKE) SERVICE_NAME=gateway lint-chart
	$(MAKE) SERVICE_NAME=orders lint-chart
	$(MAKE) SERVICE_NAME=products lint-chart

test-chart:
	helm upgrade $(SERVICE_NAME) charts/$(SERVICE_NAME) --install \
	--namespace=$(NAMESPACE) --kube-context $(CONTEXT) \
	--dry-run --debug --set image.tag=$(TAG)

install-chart:
	helm upgrade $(SERVICE_NAME) charts/$(SERVICE_NAME) --install \
	--namespace=$(NAMESPACE) --kube-context=$(CONTEXT) \
	--set image.tag=$(TAG)

lint-chart:
	helm lint charts/$(SERVICE_NAME) --strict
