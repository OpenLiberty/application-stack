#!/bin/bash

# Generates application stack artifacts.
generate() {
    # Base customization.
    mkdir -p generated
    sed -e "s!{{.LIBERTY_RUNTIME_VERSION}}!$LIBERTY_RUNTIME_VERSION!; s!{{.STACK_IMAGE}}!$STACK_IMAGE!; s!{{.DEVFILE_DOCKERFILE_LOC}}!$DEVFILE_DOCKERFILE_LOC!; s!{{.DEVFILE_DEPLOY_YAML_LOC}}!$DEVFILE_DEPLOY_YAML_LOC!; s!{{.WLP_INSTALL_PATH}}!$WLP_INSTALL_PATH!" templates/devfile.yaml > generated/devfile.yaml
    sed -e "s!{{.BASE_OS_IMAGE}}!$BASE_OS_IMAGE!; s!{{.LIBERTY_RUNTIME_VERSION}}!$LIBERTY_RUNTIME_VERSION!; s!{{.LIBERTY_RUNTIME_ARTIFACTID}}!$LIBERTY_RUNTIME_ARTIFACTID!; s!{{.LIBERTY_RUNTIME_GROUPID}}!$LIBERTY_RUNTIME_GROUPID!; s!{{.ECLIPSE_MP_API_PREV_VERSION}}!$ECLIPSE_MP_API_PREV_VERSION!; s!{{.LIBERTY_MP_FEATURE_PREV_VERSION}}!$LIBERTY_MP_FEATURE_PREV_VERSION!; s!{{.WLP_INSTALL_PATH}}!$WLP_INSTALL_PATH!" templates/stackimage/Dockerfile > generated/stackimage-Dockerfile

    # Outer loop customization of Dockerfile
    sed -e "s!{{.STACK_IMAGE}}!$STACK_IMAGE!; s!{{.LIBERTY_IMAGE}}!$LIBERTY_IMAGE!; s!{{.WLP_INSTALL_PATH}}!$WLP_INSTALL_PATH!" templates/outer-loop/Dockerfile > generated/Dockerfile
}

# Build the stack image 
buildStackImage() {
    cd stackimage
    cp ../generated/stackimage-Dockerfile Dockerfile
    docker build -t $STACK_IMAGE .
    rm -f Dockerfile
}

# Execute the specified action. The generate action is the default if none is specified.
ACTION="generate"
if [ $# -ge 1 ]; then
    ACTION=$1
    shift
fi
case "${ACTION}" in
    generate)
        generate
    ;;
    buildStackImage)
        buildStackImage
    ;;
    *)
    echo "Invalid input action. Allowed action values: generate | buildStackImage. Default: generate."
    exit 1
    ;;
esac
