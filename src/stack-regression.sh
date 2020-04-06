#!/bin/bash

#######################################################
# stack-regression.sh
# The purpose of this script is to run different stack
# project with different scenarios to attempt to regression
# test any changes in the local repository
######################################################

check_results() {
 results=`cat test.log | grep "Test of STACK completed Successfully!!!!"`
 if [[ -z $results ]]; then
   echo " "
   echo "!!!!!!!!!!!!!!!!!!!!!!!!!!"
   echo "Test of $1  failed!"
   echo "Log can be viewed at /tmp/$1/test.log"
   echo "!!!!!!!!!!!!!!!!!!!!!!!!!"
   echo " "
 else
   echo " "
   echo "!!!!!!!!!!!!!!!!!!!!!!!!!!"
   echo "Test of $1 completed Successfully!"
   echo "!!!!!!!!!!!!!!!!!!!!!!!!!!"
   echo " "
 fi
}

./test-project.sh -g git@github.com:uberskigeek/AppsodyBinaryProjectTest.git -p /TangoApp_war/ -h N > test.log
check_results AppsodyBinaryProjectTest

./test-project.sh -g git@github.com:uberskigeek/appsody-projects.git > test.log
check_results appsody-projects

./test-project.sh -a dev.local -s java-openliberty > test.log
check_results test_java-openliberty


