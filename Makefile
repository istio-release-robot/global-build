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
LOCAL_ARTIFACTS_DIR := $(abspath ../artifacts)
ARTIFACTS_TMPL := artifacts.template.yaml
ARTIFACTS_DIR ?= $(LOCAL_ARTIFACTS_DIR)
HUB ?= gcr.io/istio-testing
TAG ?= $(shell date '+%Y%m%d')-$(shell repo manifest -r | sha256sum | head -c 10)

# Where to find other modules
ISTIO_GO := ../go/src/istio.io
GO_SRCS := $(ISTIO_GO)/istio
SUBDIRS := $(GO_SRCS) ../src/proxy

# Targets that need to be implemented by other modules
TOPTARGETS := check clean build test artifacts

export GOPATH = $(shell realpath ../go)

$(TOPTARGETS): $(SUBDIRS)
$(SUBDIRS):
	$(MAKE) -C $@ $(MAKECMDGOALS)

clean:
	rm -rf $(ARTIFACTS_DIR)

artifacts:
	mkdir -p $(LOCAL_ARTIFACTS_DIR)
	repo manifest -r -o $(LOCAL_ARTIFACTS_DIR)/build.xml
	cp $(ARTIFACTS_TMPL) "$(LOCAL_ARTIFACTS_DIR)/artifacts.yaml"
	sed -i=i.bak "s|{HUB}|$(HUB)|" "$(LOCAL_ARTIFACTS_DIR)/artifacts.yaml"
	sed -i=i.bak "s|{TAG}|$(TAG)|" "$(LOCAL_ARTIFACTS_DIR)/artifacts.yaml"
	rm "$(LOCAL_ARTIFACTS_DIR)/artifacts.yaml=i.bak"

green_build:
ifndef GIT_BRANCH
	$(error GIT_BRANCH is not set)
endif
ifdef NETRC
	cp $(NETRC)/.netrc $(HOME)
endif
	$(eval CLONE_DIR := $(shell mktemp -d))
	git clone https://github.com/istio/green-builds -b $(GIT_BRANCH) $(CLONE_DIR)
	cd $(CLONE_DIR) \
	&& git checkout -b $(TAG) \
	&& cp $(LOCAL_ARTIFACTS_DIR)/{artifacts.yaml,build.xml} . \
	&& git add . \
	&& git commit -m "New Green Build for $(TAG)" \
	&& git push origin $(TAG):$(GIT_BRANCH) \
	&& rm -rf $(CLONE_DIR)

.PHONY: $(TOPTARGETS) $(SUBDIRS) green_build
