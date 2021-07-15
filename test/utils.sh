#!/bin/bash

# buildStackImage builds the base Open Liberty application stack image.
buildStackImage() {

    echo "> Building Stack Image";
    docker run --rm -it --network=host alpine ash -c "apk add socat && socat TCP-LISTEN:5000,reuseaddr,fork TCP:$(minikube ip):5000"

    docker build -t localhost:5000/test-image --build-arg stacklabel=$SHA -f generated/stackimage-Dockerfile stackimage
    docker push localhost:5000/test-image
}

# buildStack builds the Open Liberty stack repository.
buildStack() {
    echo "> Building Stack";
    export STACK_IMAGE=localhost:5000/test-image
    ./build-ol.sh
    ls -al generated
}

# installOpenLibertyOperator installs the Open Liberty operator.
installOpenLibertyOperator() {
    echo -e "\n> Installing Open Liberty operator CRDs"
    kubectl apply -f https://raw.githubusercontent.com/OpenLiberty/open-liberty-operator/master/deploy/releases/0.7.0/openliberty-app-crd.yaml

    echo -e "\n> Installing Open Liberty operator cluster level roles"
    curl -L https://raw.githubusercontent.com/OpenLiberty/open-liberty-operator/master/deploy/releases/0.7.0/openliberty-app-cluster-rbac.yaml \
      | sed -e "s/OPEN_LIBERTY_OPERATOR_NAMESPACE/default/" \
      | kubectl apply -f -

    echo -e "\n> Creating an Open Liberty application operator CR instance"
    curl -L https://raw.githubusercontent.com/OpenLiberty/open-liberty-operator/master/deploy/releases/0.7.0/openliberty-app-operator.yaml \
      | sed -e "s/OPEN_LIBERTY_WATCH_NAMESPACE/\"\"/" \
      | kubectl apply -n default -f -

    echo -e "\n> Wait for the Open Liberty operator application CR instance pod to start"
    count=1
    while [[ $(kubectl get pods -n default -l name=open-liberty-operator  -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do 
        kubectl get pods -n default
        echo "waiting for the Open Liberty operator application CR instance pod" && sleep 3; 
        count=`expr $count + 1`
        if [ $count -eq 20 ]; then
            echo "Timed out waiting for the Open Liberty operator application CR instance pod to start. Pod Config:"
            printPodConfig "name=open-liberty-operator" "default"
            echo "Open Liberty operator application CR instance pod log:"
            printPodLog "name=open-liberty-operator" "default"
            exit 12
        fi
    done
}

# printPodConfig prints pod information associated to the input label and namespace.
# Parm 1: The label (key=value) that identifies the pod of interest.
# Parm 2: The namespace where the target pod is deployed.
printPodConfig() {
    podname=$(kubectl get pod -l $1 -n $2 -o jsonpath='{.items[*].metadata.name}')
    if [[ ! -z $podname ]]; then
        kubectl describe pod $podname -n $2
    else
        echo "Pod with label $1 in namespace $2 was not found.";
    fi
}

# printPodLog prints the pod log associated to the input label and namespace.
# Parm 1: The label (key=value) that identifies the pod of interest.
# Parm 2: The namespace where the target pod is deployed.
printPodLog() {
    podname=$(kubectl get pod -l $1 -n $2 -o jsonpath='{.items[*].metadata.name}')
    if [[ ! -z $podname ]]; then
        kubectl logs $podname -n $2
    else
        echo "Pod with label $1 in namespace $2 was not found.";
    fi
}

# printLibertyServerMsgLog prints the Open Liberty server messages.log running 
# on the pod associated to the input label and namespace.
# Parm 1: The label (key=value) that identifies the pod of interest.
# Parm 2: The namespace where the target pod is deployed.
# Parm 3: The path of the Open Liberty Liberty logs directory.
printLibertyServerMsgLog() { 
    podname=$(kubectl get pod -l $1 -n $2 -o jsonpath='{.items[*].metadata.name}')
    if [[ ! -z $podname ]]; then
        kubectl exec $podname -n $2 -- ls $3/messages.log
        rc=$?
        if [ $rc -eq 0 ]; then
            kubectl exec $podname -n $2 -- cat $3/messages.log
        else
            echo "Liberty messages.log not found in pod with label $1, namespace $2, and log path $3";
        fi
    else
        echo "Pod with label $1 in namespace $2 was not found.";
    fi
}

# checkLibertyServerLogForErrorAndWarnings searches the Open Liberty server messages.log
# for warning or error messages. If they are found, the method exits with a non-zero return code. 
# The pod running the server is located using the input label and namespace.
# Parm 1: The label (key=value) that identifies the pod of interest.
# Parm 2: The namespace where the target pod is deployed.
# Parm 3: The path of the Open Liberty Liberty logs directory.
checkLibertyServerLogForErrorAndWarnings() {
    warnErrFound=$(printLibertyServerMsgLog $1 $2 $3 | grep -E "^.*[EW] .*[0-9]{4}[EW]:.*$")
    if [[ ! -z $warnErrFound ]]; then
        echo $warnErrFound
        exit 12
    fi
}

# printLibertyDebugData prints debug data associated to the open liberty pod deployment.
# Parm 1: The label (key=value) that identifies the pod of interest.
# Parm 2: The namespace where the target pod is deployed.
# Parm 3: The path of the Open Liberty Liberty logs directory.
printLibertyDebugData() {
    echo "Pod (hosting liberty server) config:"
    printPodConfig $1 $2
    echo "Pod (hosting liberty server) log:"
    printPodLog $1 $2
    echo "liberty server messages.log:"
    printLibertyServerMsgLog $1 $2 $3
}

# Execute the specified action.
if [ $# -ge 1 ]; then
    COMMAND=$1
fi
case "${COMMAND}" in
    buildStackImage)
        buildStackImage
    ;;
    buildStack)
        buildStack
    ;;
     installOpenLibertyOperator)
        installOpenLibertyOperator
    ;;
    printPodConfig)
        printPodConfig $2 $3
    ;;
    printPodLog)
        printPodLog $2 $3
    ;;
    printLibertyServerMsgLog)
        printLibertyServerMsgLog $2 $3 $4
    ;;
    printLibertyDebugData)
        printLibertyDebugData $2 $3 $4
    ;;
    checkLibertyServerLogForErrorAndWarnings)
        checkLibertyServerLogForErrorAndWarnings $2 $3 $4
    ;;
    *)
    echo "Invalid command. Allowed values: buildStackImage, buildStack, installOpenLibertyOperator, printPodConfig, printPodLog, printLibertyServerMsgLog, printLibertyDebugData, and checkLibertyServerLogForErrorAndWarnings"
    exit 1
    ;;
esac