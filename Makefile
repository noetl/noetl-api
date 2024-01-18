GHCR_USERNAME=noetl
VERSION="0.1.0"
K8S_DIR=k8s

# define get_nats_port
# $(shell kubectl get svc nats -n nats -o=jsonpath='{.spec.ports[0].nodePort}')
# endef
# NATS_URL=nats://localhost:$(call get_nats_port)

NATS_URL=nats://localhost:32222


API_SERVICE_NAME=noetl-api
API_DOCKERFILE_BASE=docker/api/Dockerfile-base
API_DOCKERFILE=docker/api/Dockerfile
API_VERSION=latest
API_BASE_VERSION=latest
API_SERVICE_TAG=local/$(API_SERVICE_NAME):$(API_VERSION)
API_SERVICE_BASE_TAG=local/noetl-api-base:$(API_BASE_VERSION)

PYTHON := python3.11
VENV_NAME := .venv
REQUIREMENTS := requirements.txt


.PHONY: venv requirements activate

venv:
	@echo "Creating Python virtual environment..."
	$(PYTHON) -m venv $(VENV_NAME)
	@. $(VENV_NAME)/bin/activate; \
	pip3 install --upgrade pip; \
	deactivate
	@echo "Virtual environment created."

requirements:
	@echo "Installing python requirements..."
	@. $(VENV_NAME)/bin/activate; \
	pip3 install -r $(REQUIREMENTS); \
	$(PYTHON) -m spacy download en_core_web_sm; \
	echo "Requirements installed."

activate-venv:
	@. $(VENV_NAME)/bin/activate;

activate-help:
	@echo "To activate the virtual environment:"
	@echo "source $(VENV_NAME)/bin/activate"

install-helm:
	@echo "Installing Helm..."
	@brew install helm
	@echo "Helm installation complete."


install-nats-tools:
	@echo "Tapping nats-io/nats-tools..."
	@brew tap nats-io/nats-tools
	@echo "Installing nats from nats-io/nats-tools..."
	@brew install nats-io/nats-tools/nats
	@echo "NATS installation complete."


.PHONY: venv requirements activate-venv activate-help install-helm install-nats-tools



#[BUILD]#######################################################################
.PHONY: build-api-base build-api remove-api-image remove-base-image rebuild-api  build-all clean

build-api-base:
	@echo "Building API Base image..."
	docker build --no-cache --build-arg PRJ_PATH=../.. -f $(API_DOCKERFILE_BASE) -t $(API_SERVICE_BASE_TAG) .


remove-base-image:
	@echo "Removing API base Docker images..."
	docker rmi $(API_SERVICE_BASE_TAG)

remove-api-image:
	@echo "Removing API image..."
	docker rmi $(API_SERVICE_TAG)

build-base-images:  build-api-base build-plugin-base

build-api:
	@echo "Building API image..."
	docker build --no-cache --build-arg PRJ_PATH=../.. -f $(API_DOCKERFILE) -t $(API_SERVICE_TAG) .

rebuild-api: remove-api-image build-api

build-all: build-api-base build-api

clean:
	docker rmi $$(docker images -f "dangling=true" -q)

#[TAG]#######################################################################
.PHONY: tag-api

tag-api:
	@echo "Tagging API image"
	docker tag $(API_SERVICE_TAG) ghcr.io/$(GHCR_USERNAME)/noetl-api:$(API_VERSION)

#[PUSH]#######################################################################
.PHONY: push-api
.PHONY: docker-login push-all

push-all:push-api

docker-login:
	@echo "Logging in to GitHub Container Registry"
	@echo $$PAT | docker login ghcr.io -u noetl --password-stdin

push-api: tag-api docker-login
	@echo "Pushing API image to GitHub Container Registry"
	docker push ghcr.io/$(GHCR_USERNAME)/noetl-api:$(API_VERSION)

#[DEPLOY]#######################################################################
.PHONY: create-ns deploy deploy-local deploy-api

deploy-all: create-ns deploy-api
deploy-local: create-ns deploy-api-local

create-ns:
	@echo "Creating NoETL namespace..."
	kubectl config use-context docker-desktop
	kubectl apply -f $(K8S_DIR)/noetl/namespace.yaml

deploy-api:
	@echo "Deploying NoETL API service from ghcr.io ..."
	kubectl config use-context docker-desktop
	kubectl apply -f $(K8S_DIR)/noetl/api/deployment.yaml
	kubectl apply -f $(K8S_DIR)/noetl/api/service.yaml

deploy-local:
	@echo "Deploying NoETL API service from local image..."
	kubectl config use-context docker-desktop
	kubectl apply -f $(K8S_DIR)/noetl/api-local/deployment.yaml
	kubectl apply -f $(K8S_DIR)/noetl/api-local/service.yaml


.PHONY: delete-ns delete-all-deploy delete-all-local-deploy  delete-api-deploy

delete-all-deploy: delete-api-deploy
delete-all-local-deploy: delete-api-local-deploy

delete-ns:
	@echo "Deleting NoETL namespace..."
	kubectl config use-context docker-desktop
	kubectl delete -f $(K8S_DIR)/noetl/namespace.yaml

delete-api-deploy:
	@echo "Deleting NoETL API Service"
	kubectl config use-context docker-desktop
	kubectl delete -f $(K8S_DIR)/noetl/api/deployment.yaml -n noetl
	kubectl delete -f $(K8S_DIR)/noetl/api/service.yaml -n noetl

delete-api-local-deploy:
	@echo "Deleting NoETL API Service"
	kubectl config use-context docker-desktop
	kubectl delete -f $(K8S_DIR)/noetl/api-local/deployment.yaml -n noetl
	kubectl delete -f $(K8S_DIR)/noetl/api-local/service.yaml -n noetl

#[WORKFLOW COMMANDS]######################################################################

register-plugin: activate-venv
    ifeq ($(PLUGIN_NAME),)
	    @echo "Usage: make register-plugin PLUGIN_NAME=\"http-handler:0_1_0\" IMAGE_URL=\"local/noetl-http-handler:latest\""
    else
	    $(PYTHON) noetl/cli.py register plugin  $(PLUGIN_NAME) $(IMAGE_URL)
    endif

list-plugins: activate-venv
	$(PYTHON) noetl/cli.py list plugins

describe-plugin: activate-venv
	$(PYTHON) noetl/cli.py describe plugin $(filter-out $@,$(MAKECMDGOALS))

register-playbook: activate-venv
    ifeq ($(WORKFLOW),)
	    @echo "Usage: make register-playbook WORKFLOW=playbooks/time/fetch-world-time.yaml"
    else
	    $(PYTHON) noetl/cli.py register playbook $(WORKFLOW)
    endif

list-playbooks: activate-venv
	$(PYTHON) noetl/cli.py list playbooks

%:
	@:
describe-playbook: activate-venv %
	$(PYTHON) noetl/cli.py describe playbook $(filter-out $@,$(MAKECMDGOALS))

run-playbook-fetch-time-and-notify-slack: activate-venv
	$(PYTHON) noetl/cli.py run playbook fetch-time-and-notify-slack '{"TIMEZONE":"$(TIMEZONE)","NOTIFICATION_CHANNEL":"$(NOTIFICATION_CHANNEL)"}'


.PHONY: register-playbook list-playbooks list-plugins describe-playbook describe-plugin run-playbook-fetch-time-and-notify-slack

.PHONY: show-events show-commands
show-events:
	$(PYTHON) noetl/cli.py show events

show-commands:
	$(PYTHON) noetl/cli.py show commands


#[KUBECTL COMMANDS]######################################################################

.PHONY: logs
logs:
	kubectl logs -f -l 'app in (noetl-api)'


#[PIP UPLOAD]############################################################################
.PHONY: pip-upload

pip-upload:
	rm -rf dist/*
	$(PYTHON) setup.py sdist bdist_wheel
	$(PYTHON) -m twine upload dist/*
