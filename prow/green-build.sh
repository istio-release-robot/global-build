#!/bin/bash

# Copyright 2017 Istio Authors

#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at

#       http://www.apache.org/licenses/LICENSE-2.0

#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.


#######################################
# Presubmit script triggered by Prow. #
#######################################

MAKEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Exit immediately for non zero status
set -e
# Check unset variables
set -u
# Print commands
set -x

echo '=== Bazel Build ==='
make -C ${MAKEDIR} build

echo '=== Code Check ==='
make -C ${MAKEDIR} check

echo '=== Bazel Tests ==='
make -C ${MAKEDIR} test

echo '=== Build Artifacts ==='
make -C ${MAKEDIR} artifacts

#echo "=== Pushing Artifacts ==="
#make -C ${MAKEDIR} push

# GITHUB_TOKEN needs to be set
if [[ ${CI:-} == 'bootstrap' ]]; then
  GITHUB_TOKEN_PATH='/etc/github/oauth' GIT_BRANCH="$(PULL_BASE_REF)" make -C ${MAKEDIR} green_build
fi
