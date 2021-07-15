#!/bin/bash

echo -e "\n> Get new stack image version"
stackImage=$(cat build-ol.sh | grep "openliberty/application-stack:")
stackImageVersion=$(echo ${stackImage##*:} | sed 's/\}\"//')
echo "New stack image version: $stackImageVersion"

echo -e "\n> Make stacktest regression dir"
mkdir stacktest-reg
cd stacktest-reg

# Get the currently released version of the devfile template and generate
# this will allow us to run the current devfile with the new stack image
# introduced via this current PR being tested
echo -e "\n> Clone the main branch stack repo"
git clone https://github.com/OpenLiberty/application-stack.git
cd application-stack

echo -e "\n> Check new stack image version"
currentStackImage=$(cat build-ol.sh | grep "openliberty/application-stack:")
currentStackImageVersion=$(echo ${currentStackImage##*:} | sed 's/\}\"//')

echo "Current stack image version: $currentStackImageVersion"
echo "New stack image version: $stackImageVersion"

currVerArray=( ${currentStackImageVersion//./ } )  
newVerArray=( ${stackImageVersion//./ } ) 

if [[ "$currentStackImageVersion" == "$stackImageVersion" ]]; then
    echo "SKIPPING - Stack image version has not changed. No need to regression test.";
    exit 0;
elif [[ newVerArray[0] -ne currVerArray[0] || newVerArray[1] -ne currVerArray[1] ]]; then
    echo "SKIPPING - New major.minor stack image. No need to regression test";
    exit 0;
else
    echo "Micro version change detected - running regression test";
fi

echo -e "\n> Run buildStack from the main branch in stack repo that was just cloned"
./test/utils.sh buildStack

echo -e "\n> Make a test app dir for test project"
mkdir devfile-regression-inner-loop-test-dir
cd devfile-regression-inner-loop-test-dir

echo -e "\n> Clone application-stack-intro project"
git clone https://github.com/OpenLiberty/application-stack-intro.git
cd application-stack-intro

# This is a copy of the 'main' version of the devfile - vs an updated devfile from this PR.
# vis-a-vie the fact that we git cloned the main branch of the stack repo above
echo -e "\n> Copy devfile and scripts"
cp ../../generated/devfile.yaml devfile.yaml

# This is a workaround to avoid surefire fork failures when running
# the GHA test suite.
# Issue #138 has been opened to track and address this
# add the -DforkCount arg to the odo test cmd only for this run
echo -e "\n> Modifying the odo test command"
sed -i 's/failsafe:integration-test/-DforkCount=0 failsafe:integration-test/' devfile.yaml

echo -e "\n Updated devfile contents:"
cat devfile.yaml

# Call common script here
# the only accomodation we have to make is that
# we are one dir level deeper from the GHA test dir
echo -e "\n> Base Inner loop test run"
COMP_NAME=my-ol-component PROJ_NAME=devfile-regression-inner-loop-test ./../../../../test/inner-loop/base-inner-loop.sh
rc=$?
if [ $rc -ne 0 ]; then
    exit 12
fi

echo -e "\n> Cleanup: Delete created directories"
echo $PWD; cd ../../../..; echo $PWD; ls -l; rm -rf stacktest-reg; echo $PWD; ls -l; 
