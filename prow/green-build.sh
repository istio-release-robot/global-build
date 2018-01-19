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

# Checking the build if already up to date
SKIP_BUILD=true
MANIFEST_DIR=$(mktemp -d)
NEW_BUILD_MANIFEST="${MANIFEST_DIR}/new_build.xml"
OLD_BUILD_MANIFEST="${MANIFEST_DIR}/old_build.xml"
wget "https://raw.githubusercontent.com/istio/green-builds/${GIT_BRANCH}/build.xml" -O "${OLD_BUILD_MANIFEST}"
repo manifest -r -o ${NEW_BUILD_MANIFEST}
diff ${NEW_BUILD_MANIFEST} ${OLD_BUILD_MANIFEST} || SKIP_BUILD=false

if [[ ${SKIP_BUILD} == true ]]; then
  echo "Skipping Build: Green build up to date."
  exit 0
fi

function test_sha_in_repo() {
   SHA_REGEX=$1
   FILE=$2

   if ! grep -q $SHA_REGEX $FILE; then
     echo "#### Inconsistent shas: $SHA_REGEX not found in $FILE" >&2
     # inconsistent shas, not a green build candidate, don't flag it as error
     # exit 0 TODO reenable when ready
   fi
}

# test_consistent_shas tests if the shas are consistent if not it exits
# because grep fails to find the shas in the required files
function test_consistent_shas() {
    local NEW_BLD_MANIFEST=$1
    ISTIO_API_SHA=`  grep istio/api         ${NEW_BLD_MANIFEST} | cut -f 6 -d \"`
    MIXERCLIENT_SHA=`grep istio/mixerclient ${NEW_BLD_MANIFEST} | cut -f 6 -d \"`
    PROXY_SHA=`      grep istio/proxy       ${NEW_BLD_MANIFEST} | cut -f 6 -d \"`

    #is the istio api sha being used in istio?
    test_sha_in_repo                $ISTIO_API_SHA  ../go/src/istio.io/istio/Gopkg.toml

    #is the istio api sha being used in mixerclient?
    test_sha_in_repo    ISTIO_API.*$ISTIO_API_SHA   ../src/mixerclient/repositories.bzl

    #is the mixerclient sha being used in proxy?
    test_sha_in_repo MIXER_CLIENT.*$MIXERCLIENT_SHA ../src/proxy/src/envoy/mixer/repositories.bzl

    #is the proxy sha being used in istio repo?
    test_sha_in_repo               $PROXY_SHA       ../go/src/istio.io/istio/pilot/docker/Dockerfile.proxy
}

export KUBECONFIG=${HOME}/.kube/config
if [[ ${CI:-} == 'bootstrap' ]]; then
  export KUBECONFIG=/home/bootstrap/.kube/config
fi
echo '=== Build ==='
make -C ${MAKEDIR} build

echo '=== Code Check ==='
make -C ${MAKEDIR} check

echo '=== Tests ==='
#make -C ${MAKEDIR} test

echo '=== Build Artifacts ==='
make -C ${MAKEDIR} artifacts

# GITHUB_TOKEN needs to be set
if [[ ${CI:-} == 'bootstrap' ]]; then
  set +e
  (cd $MAKEDIR ; test_consistent_shas ${NEW_BUILD_MANIFEST} )
  set -e

  make -C ${MAKEDIR} green_build
fi
