#!/bin/bash

# Component name. 
COMP_NAME="${COMP_NAME:-default-component}"

# Namespace/project name.
PROJ_NAME="${PROJ_NAME:-default-test}"

# Liberty server config directory path.
LIBERTY_SERVER_LOGS_DIR_PATH='/opt/ol/wlp/usr/servers/defaultServer/logs'

# Base inner loop test using ODO.
echo -e "\n> Create new odo project"
odo project create $PROJ_NAME

echo -e "\n> Create new odo component"
odo create $COMP_NAME

echo -e "\n> Create URL with Minikube IP"
odo url create --host $(minikube ip).nip.io --ingress

echo -e "\n> ODO env:"
cat .odo/env/env.yaml

echo -e "\n> Checking on ingress readiness"
kubectl get pods -n kube-system 

echo -e "\n> Push to Minikube"
odo push
rc=$?
if [ $rc -ne 0 ]; then
    echo "\n> Retrying odo push" && sleep 5
    odo push -v 4 --show-log
    rc=$?
    if [ $rc -ne 0 ]; then 
      exit 12
    fi
fi

echo -e "\n> Wait for the intro application to become available"
count=1
while ! odo log | grep -q "CWWKZ0003I: The application intro updated"; do 
    echo "Waiting for the intro application to become available... " && sleep 3
    count=`expr $count + 1`
    if [ $count -eq 40 ]; then
        echo "Timed out waiting for the intro application to become available"
        ./../../test/utils.sh printLibertyDebugData "component=$COMP_NAME" $PROJ_NAME $LIBERTY_SERVER_LOGS_DIR_PATH
        exit 12
    fi
done

echo -e "\n> Test liveness endpoint"
livenessResults=$(curl http://ep1.$(minikube ip).nip.io/health/live)
count=1
while ! echo $livenessResults | grep -qF '{"checks":[{"data":{},"name":"SampleLivenessCheck","status":"UP"}],"status":"UP"}'; do 
    echo "Waiting for liveness check to pass... " && sleep 3
    count=`expr $count + 1`
    if [ $count -eq 20 ]; then
        echo "Timed out waiting for liveness check to pass. Liveness results:"
        echo $livenessResults
        ./../../test/utils.sh printLibertyDebugData "component=$COMP_NAME" $PROJ_NAME $LIBERTY_SERVER_LOGS_DIR_PATH
        exit 12
    fi
done

echo -e "\n> Test readiness endpoint"
readinessResults=$(curl http://ep1.$(minikube ip).nip.io/health/ready)
count=1
while ! echo $readinessResults | grep -qF '{"checks":[{"data":{},"name":"SampleReadinessCheck","status":"UP"}],"status":"UP"}'; do 
    echo "Waiting for readiness check to pass... " && sleep 3
    count=`expr $count + 1`
    if [ $count -eq 20 ]; then
        echo "Timed out waiting for Readiness check to pass. Readiness results:"
        echo $readinessResults
        ./../../test/utils.sh printLibertyDebugData "component=$COMP_NAME" $PROJ_NAME $LIBERTY_SERVER_LOGS_DIR_PATH
        exit 12
    fi
done

echo -e "\n> Test REST endpoint"
restResults=$(curl http://ep1.$(minikube ip).nip.io/health/live)
if ! echo $restResults | grep -qF 'Hello! Welcome to Open Liberty'; then
    echo "REST endpoint check passed!"
else
    echo "REST endpoint check failed. REST endpoint returned:"
    echo $restResults
    ./../../test/utils.sh printLibertyDebugData "component=$COMP_NAME" $PROJ_NAME $LIBERTY_SERVER_LOGS_DIR_PATH
    exit 12
fi

echo -e "\n> Run odo test"
odo test
rc=$?
if [ $rc -ne 0 ]; then
    echo "\n> Retrying odo test" && sleep 5
    odo test -v 4 --show-log
    rc=$?
    if [ $rc -ne 0 ]; then
        echo "Odo test run failed:"
        ./../../test/utils.sh printLibertyDebugData "component=$COMP_NAME" $PROJ_NAME $LIBERTY_SERVER_LOGS_DIR_PATH
        exit 12
    fi
fi

echo -e "\n> Cleanup: Delete component"
odo delete -a -f
count=1
while [ ! -z $(kubectl get pod -l component=$COMP_NAME -o jsonpath='{.items[*].metadata.name}') ]; do
    echo "Waiting for component pod to be terminated..." && sleep 3
    count=`expr $count + 1`
    if [ $count -eq 20 ]; then
        echo "Timed out waiting for component pod to be terminated"
        ./../../test/utils.sh printLibertyDebugData "component=$COMP_NAME" $PROJ_NAME $LIBERTY_SERVER_LOGS_DIR_PATH
        exit 12
    fi
done

echo -e "\n> Cleanup: Delete project"
odo project delete $PROJ_NAME -f
count=1
while odo project list | grep -q $PROJ_NAME; do 
    echo "Waiting for project to be deleted..." && sleep 3
    count=`expr $count + 1`
    if [ $count -eq 20 ]; then
        echo "Timed out waiting for project $PROJECT_NAME to be deleted. Namespace information:"
        kubectl get namespace $PROJECT_NAME -o yaml
        exit 12
    fi
done