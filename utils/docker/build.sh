#!/bin/bash -ex
#
# Copyright 2016-2017, Intel Corporation
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions
# are met:
#
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in
#       the documentation and/or other materials provided with the
#       distribution.
#
#     * Neither the name of the copyright holder nor the names of its
#       contributors may be used to endorse or promote products derived
#       from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
# "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
# LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
# A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
# OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
# LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
# DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
# THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#
# build.sh - runs a Docker container from a Docker image with environment
#            prepared for building this project.
#

if [[ -z "$OS" || -z "$OS_VER" ]]; then
	echo "ERROR: The variables OS and OS_VER have to be set properly " \
		"(eg. OS=ubuntu, OS_VER=16.04)."
	exit 1
fi

if [[ -z "$HOST_WORKDIR" ]]; then
	echo "ERROR: The variable HOST_WORKDIR has to contain a path to " \
		"the root of this project on the host machine"
	exit 1
fi

chmod -R a+w $HOST_WORKDIR

if [[ "$TRAVIS_EVENT_TYPE" == "cron" || "$TRAVIS_BRANCH" == "coverity_scan" ]]; then
	if [[ $TYPE != coverity ]]; then
		echo "Skipping non-Coverity job for cron/Coverity build"
		exit 0
	fi
else
	if [[ $TYPE = "coverity" ]]; then
		echo "Skipping Coverity job for non cron/Coverity build"
		exit 0
	fi
fi

imageName=${DOCKERHUB_REPO}:${OS}-${OS_VER}
containerName=pmemfile-${OS}-${OS_VER}

if [[ "$command" == "" ]]; then
	case $TYPE in
		normal)
			command="./run-build.sh";
			;;
		package)
			command="./run-build-package.sh";
			;;
		sqlite)
			command="external_tests/run-build-suite.sh sqlite"
			docker_opts="--ulimit nofile=1024:1024";
			;;
		ltp)
			command="external_tests/run-build-suite.sh ltp"
			docker_opts="--ulimit nofile=1024:1024";
			;;
		coverity)
			command="./run-coverity.sh";
			;;
		pjdfstest)
			command="pjdfstest/build-and-test.sh";
			docker_opts="-u root";
			;;
		coverage)
			command="./run-coverage.sh";
			;;
	esac

	if [ $TYPE = "coverage" -o "$COVERAGE" = "1" ]; then
		docker_opts="${docker_opts} `bash <(curl -s https://codecov.io/env)`";
	fi
fi

WORKDIR=/pmemfile-${OS}-${OS_VER}

# Run a container with
#  - environment variables set (--env)
#  - host directory containing pmemfile source mounted (-v)
#  - working directory set (-w)
docker run --rm --privileged=true --name=$containerName $EXTRA_DOCKER_ARGS -i \
	${docker_opts} \
	--env http_proxy=$http_proxy \
	--env https_proxy=$https_proxy \
	--env C_COMPILER=$C_COMPILER \
	--env CPP_COMPILER=$CPP_COMPILER \
	--env WORKDIR=$WORKDIR \
	--env TRAVIS=$TRAVIS \
	--env TRAVIS_COMMIT_RANGE=$TRAVIS_COMMIT_RANGE \
	--env TRAVIS_COMMIT=$TRAVIS_COMMIT \
	--env TRAVIS_REPO_SLUG=$TRAVIS_REPO_SLUG \
	--env TRAVIS_BRANCH=$TRAVIS_BRANCH \
	--env TRAVIS_EVENT_TYPE=$TRAVIS_EVENT_TYPE \
	--env COVERITY_SCAN_TOKEN=$COVERITY_SCAN_TOKEN \
	--env COVERITY_SCAN_NOTIFICATION_EMAIL=$COVERITY_SCAN_NOTIFICATION_EMAIL \
	--env AUTOGENSOURCES=$AUTOGENSOURCES \
	--env COVERAGE=$COVERAGE \
	-v $HOST_WORKDIR:$WORKDIR \
	-w $WORKDIR/utils/docker \
	$imageName $command
