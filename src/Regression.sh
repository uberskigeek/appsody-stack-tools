#!/bin/sh

#######################################################
# Regression.sh
# The purpose of this script is to run different stack
# project with different scenarios to attempt to regression
# test any changes in the local repository
######################################################

check_results() {
 results=`cat test.log | grep "Test of STACK completed Successfully!!!!"`
 if [[ -z $results ]]; then
   echo "Test of $1 stack failed!"
   mv test.log $1_test.log
 else
   echo "Test of $1 stack completed Successfully!"
 fi
}

./test-stack.sh -g git@github.com:uberskigeek/AppsodyBinaryProjectTest.git -c /TangoApp_war/ -h N > test.log
check_results BinaryStack

./test-stack.sh -g git@github.com:uberskigeek/appsody-projects.git > test.log
check_results PrebuiltStack

./test-stack.sh -a dev.local -s java-openliberty > test.log
check_results InitRunAndBuild


