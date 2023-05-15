HOST ?= localhost
NAMESPACE ?= jenkins
CONTEXT ?= kind-$(NAMESPACE)
LOCAL_DNS ?= 127.0.0.1.sslip.io

kind-create-cluster:
	kind create cluster --config kind-config.yaml --name $(NAMESPACE)
	kind export kubeconfig --name $(NAMESPACE)
	NEWURL=$$(kubectl config view | grep -B1 'name: $(CONTEXT)' | grep server: | awk '{print $$2}' | sed -e 's/0.0.0.0/$(HOST)/') ; \
		kubectl config set-cluster $(CONTEXT) --server=$${NEWURL} --insecure-skip-tls-verify=true

kind-setup-ingress:
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	sleep 30
	kubectl wait --namespace ingress-nginx \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=90s

undeploy:
	# $(MAKE) delete-namespace
	kind delete cluster --name $(NAMESPACE)

init-helm:
	helm repo add stable https://charts.helm.sh/stable
	helm repo update

kind-setup-cert-manager:
	kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.11.0/cert-manager.yaml
	sleep 40
	kubectl wait --namespace cert-manager \
    --for=condition=available deployment/cert-manager \
    --timeout=450s

deploy: init-helm kind-create-cluster kind-setup-ingress kind-setup-cert-manager
	helm repo add epinio https://epinio.github.io/helm-charts
	helm install epinio -n epinio --create-namespace epinio/epinio --set global.domain=$(LOCAL_DNS)
	epinio login -u admin https://epinio.$(LOCAL_DNS)

config:
	docker pull jenkins/jenkins:latest
	epinio target workspace
	epinio apps create jenkins
	$(MAKE) push
	
push:
	kind load docker-image jenkins/jenkins:latest --name $(NAMESPACE)
	epinio push -n jenkins --container-image-url $(NAMESPACE)/jenkins:latest
	echo "Initial password: " && kubectl exec $$(kubectl get pods --context=kind-jenkins --namespace workspace --no-headers=true | awk '{print $$1}')  --namespace workspace -- cat /var/jenkins_home/secrets/initialAdminPassword
test:
	
destroy:
	epinio apps delete jenkins