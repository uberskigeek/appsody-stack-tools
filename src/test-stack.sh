#!/bin/bash

# use this script to test a stack
# parameters are 
# 1) stack repository
# 2) stack name
# 3) stack test properties file. 
# 4) stack template name (optional if not specified will use default template)

#######################
# Check Application URL
#######################

checkAppURL() {
 up=`curl --dump-header - http://localhost:9080/starter/resource | grep "200 OK"`
 
  if [[ ! $up ]]; then
    result="Test of application URL indicates it is NOT up, Test Failed!!!!!!"
  else
    result="Test of application URL indicates it is up"
  fi
  echo $result
}
######################
# Check health url
#####################
checkHealthURL() {
  up=`curl http://localhost:9080/health | jq -c '[. | {status: .status}]' | grep "UP"`
  echo " up = $up" 
  if [[ ! $up ]]; then
    result="Health Status indicates the application is NOT up, Test Failed!!!!!!"
  else
    result="Health status indicates the application is up"
  fi
  echo $result
}

#####################
# Get URL and port of
# app deployed to kubernetes
####################
getDeployedURL() {
   oldIFS=$IFS
   IFS=' '
   for x in $1 
    do
       url=`cat $x | grep http`
    done
    IFS=$oldIFS
    echo $url
}

stopRun() {

   runId=`ps | grep "appsody run" | grep -v grep`
   runId=`echo $runId | head -n1 | awk '{print $1;}'`
   echo "Stopping appsody runid $runId"
   kill $runId
}

#Check parameters
if [ "$#" -lt 3 ]; then
    echo "Illegal number of parameters"
    echo "Command syntax is test-stack.sh repositoryName stackName propertiesFileName templateName"
    exit 12
fi
  appsodyNotInstalled=`appsody version | grep "command not found"`
  if [[ $appsodyNotInstalled ]]; then 
    echo "appsody is not installed Please install appsody and try again"
    exit 12
  fi 
 repository=$1
 stack=$2
 props=$3
 template=""

 stack_loc=test_$stack

 if [ "$#" -gt 3 ]; then
   template=$4
 fi

 echo " Passed arguments: "
 echo "  repository = $repository "
 echo "  stack = $stack "
 echo "  props = $props "
 echo "  template = $template"


 if [[ -f $props ]]; then 
   echo "Properties file $props cannot be found"
   exit 12
 fi

 repoExists=`appsody repo list | grep $repository`
 if [[ ! $repoExists ]]; then 
    echo "repo $repository is not available, please select a valid repository"
    exit 12
 fi

 stackInRepo=`appsody list | grep $stack | grep $repository`
 if [[ ! stackInRepo ]]; then
     echo "Stack $stack is not available in repo $repo. Please select valid stack"
     exit 12
 fi

 # create a location for the stack to be initialized
 cd /tmp
 if [[ $? -ne 0 ]]; then
   echo "temp directory not avialable exiting "
   exit 12
 fi
 mkdir $stack_loc
 if [[ $? -ne 0 ]]; then
    echo "unable to create location to install stack, exiting"
    exit 12
 fi
 cd $stack_loc
 if [[ $? -ne 0 ]]; then
   echo "unable to cd to stack install directory /tmp/$stack_loc, exiting"
   exit 12
 fi
######################### 
# initialize the stack  #
########################
 appsody init $repository/$stack $template
 if [[ $? -ne 0 ]]; then
   echo "An error has occurred initializing the stack, rc=$?"
   echo  "\nTest Failed!!!!!!\n"
   cleanup
   exit 12
 fi
###########################
# do a run from this stack #
#t##########################
# need to update this and remove hard coding of port 
# and allow user to specify the port
###################################
 appsody run -p 9444:9443 > run.log &
 
 waitMessage="Waiting for server to start"
 waitcount=1
 echo $waitMessage
 while [ $waitcount -le 300 ]
  do
    sleep 1
    waitcount=$(( $waitcount + 1 ))
    serverStarted=`cat run.log | grep "server is ready to run a smarter planet"`
    if [[ ! serverStarted ]]; then
       waitcount=301
       echo "\nServer Has Started\n"
    else
       waitcount=$(( $waitcount + 1 ))
    fi
 done
 
 if [[ ! serverStarted ]]; then 
   echo "Server has not successfully started in 6 minutes"
   echo  "\nTest Failed!!!!!!\n" 
   stopRun
   cleanup 
   exit 12 
 fi 
 
 healthURL="http://localhost:9080"
 checkHealthURL $healthURL
 echo "The result from checkHealthURL = $result"
 failed=`echo $results | grep Failed!`
 if [[ $failed ]]; then
   echo $result
   stopRun
   cleanup
   exit 12
 else
   echo "Health status indicates the application is up"
 fi

################
# Check app url
###############
appURL="http://localhost:9080"
checkAppURL $appURL
up=`echo $result | grep Failed!`
 if [[ $up ]]; then
    echo  $results
    stopRun
    cleanup
    exit 12
 else
    echo "Test of application URL indicates it is up"
 fi

 stopRun

 appsody deploy > deploy.log 2>&1 &

 while [ $waitcount -le 300 ]
  do
    sleep 1
    waitcount=$(( $waitcount + 1 ))
    serverStarted=`tail deploy.log | grep "Deployed project running at"`
    if [[ ! serverStarted ]]; then
        waitcount=301
       echo "\nServer Has Started\n"
    else
       waitcount=$(( $waitcount + 1 ))
    fi
 done

 if [[ ! serverStarted ]]; then
   echo "Server has not successfully started in 6 minutes"
   echo  "\nTest Failed!!!!!!\n"
   appsody deploy delete
   cleanup
   exit 12
 fi
 
 getDeployedURL $serverStarted
 checkHealthURL $url
 up=`echo $result | grep Failed!`
  if [[ $up ]]; then
     echo  $results
     appsody deploy delete
     cleanup
     exit 12
  else
     echo "Test of application URL indicates it is up"
  fi 
 
 checkAppURL $url
 up=`echo $result | grep Failed!`
 if [[ $up ]]; then
    echo  $results
 else
    echo "Test of application URL indicates it is up"
 fi
 appsody deploy delete 
 cleanup 
 cd /tmp
 rm -r $stack_loc
 if [[ $? -ne 0 ]]; then
   echo "non zero return code from clean up of stack install location, rc=$?"
 fi
 
