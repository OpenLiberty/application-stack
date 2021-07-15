#!/bin/bash

####
# For more documentation, see:
#  https://github.com/OpenLiberty/application-stack/wiki/Open-Liberty-Application-Stack-Customization
####

#
# Base image used to build stack image
#
BASE_OS_IMAGE="${BASE_OS_IMAGE:-adoptopenjdk/openjdk11-openj9:ubi}"

#
# Version of Liberty runtime to use within both inner and outer loops
#
LIBERTY_RUNTIME_VERSION="${LIBERTY_RUNTIME_VERSION:-21.0.0.3}"

#
# Archive Id of the Liberty runtime archive
#
LIBERTY_RUNTIME_ARTIFACTID="${LIBERTY_RUNTIME_ARTIFACTID:-openliberty-runtime}"

#
# Group Id of the Liberty runtime archive
#
LIBERTY_RUNTIME_GROUPID="${LIBERTY_RUNTIME_GROUPID:-io.openliberty}"

#
# The Liberty base image used in the final stage of the outer loop Dockerfile used to build your application image from
#
LIBERTY_IMAGE="${LIBERTY_IMAGE:-openliberty/open-liberty:21.0.0.3-full-java11-openj9-ubi}"

#
# The name and tag of the "stack image you will build.  This will used to create your inner loop development containers, and also as the base image for the first stage of your outer loop image build.
#
STACK_IMAGE="${STACK_IMAGE:-openliberty/application-stack:0.6}"

#
# URL at which your outer loop Dockerfile is hosted
#
DEVFILE_DOCKERFILE_LOC="${DEVFILE_DOCKERFILE_LOC:-https://github.com/OpenLiberty/application-stack/releases/download/outer-loop-0.5.1/Dockerfile}"

#
# URL at which your outer loop deploy YAML template is hosted
#
DEVFILE_DEPLOY_YAML_LOC="${DEVFILE_DEPLOY_YAML_LOC:-https://github.com/OpenLiberty/application-stack/releases/download/outer-loop-0.5.1/app-deploy.yaml}"

#
# The previous major microprofile spec API version supported by the stack.
#
ECLIPSE_MP_API_PREV_VERSION="${ECLIPSE_MP_API_PREV_VERSION:-3.3}"

#
# The previous OpenLiberty major microprofile feature version supported by the stack.
#
LIBERTY_MP_FEATURE_PREV_VERSION="${LIBERTY_MP_FEATURE_PREV_VERSION:-3.3}"

#
# Installation path for Liberty in official Liberty images. This is also used as the installation path for the innerloop stack image
#
WLP_INSTALL_PATH="${WLP_INSTALL_PATH:-/opt/ol/wlp}"

. ./build.sh $@
