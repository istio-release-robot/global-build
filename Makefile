## Copyright 2017 Istio Authors
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.

SHELL := /bin/bash

# Artifacts relate variables
LOCAL_ARTIFACTS_DIR = ../artifacts
ARTIFACTS_TMPL := artifacts.template.yaml
ARTIFACTS_DIR ?= $(LOCAL_ARTIFACTS_DIR)
HUB ?= gcr.io/istio-testing
TAG ?= $(shell echo "$(shell cat istio.VERSION)-$(shell date '+%Y%m%d')-$(shell repo manifest -r | sha256sum | head -c 10)")

# Where to find other modules
ISTIO_GO := ../go/src/istio.io
GO_SRCS := $(ISTIO_GO)/auth $(ISTIO_GO)/pilot $(ISTIO_GO)/mixer $(ISTIO_GO)/istio
SUBDIRS := $(GO_SRCS) ../src/proxy

# Targets that need to be implemented by other modules
TOPTARGETS := clean build setup test push

export GOPATH = $(shell realpath ../go)

$(TOPTARGETS): $(SUBDIRS)
$(SUBDIRS):
	$(MAKE) -C $@ $(MAKECMDGOALS)

.PHONY: artifacts
artifacts:
	mkdir -p ${LOCAL_ARTIFACTS_DIR}
	repo manifest -r -o ${LOCAL_ARTIFACTS_DIR}/build.xml
	cp ${ARTIFACTS_TMPL} "${LOCAL_ARTIFACTS_DIR}/artifacts.yaml"
	sed -i=i.bak "s|{HUB}|${HUB}|" "${LOCAL_ARTIFACTS_DIR}/artifacts.yaml"
	sed -i=i.bak "s|{TAG}|${TAG}|" "${LOCAL_ARTIFACTS_DIR}/artifacts.yaml"
	rm "${LOCAL_ARTIFACTS_DIR}/artifacts.yaml=i.bak"

.PHONY: green_build
green_build:
	CLONE_DIR=$(mktemp -d)
	echo ${CLONE_DIR}
	git config --global hub.protocol https
	hub clone sebastienvas/istio-green-builds -b ${PULL_BASE_REF} ${CLONE_DIR}
	cd ${CLONE_DIR}
	git checkout -b ${TAG}
	cp ${LOCAL_ARTIFACTS_DIR}/{artifacts.yaml,build.xml} .
	git add .
	git commit -m "New Green Build for ${TAG}"
	git push
	hub pull-request

.PHONY: $(TOPTARGETS) $(SUBDIRS)
