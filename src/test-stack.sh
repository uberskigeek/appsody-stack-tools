#!/bin/bash

# use this script to test a stack
# parameters are 
# 1) stack repository
# 2) stack name
# 3) stack template name (optional if not specified will use default template)

#######################
# Check Application URL
#######################

checkAppURL() {
 echo "Issueing command = curl --dump-header - $1/starter/resource | grep \"200 OK"
 waitcount=1
 while [ $waitcount -le 300 ]
 do
  sleep 1
  up=`curl --dump-header - $1/starter/resource | grep "200 OK"`
  if [[ -z $up ]]; then
    waitcount=$(( $waitcount + 1 ))
  else
   waitcount=301
  fi
 done
  if [[ -z $up ]]; then
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
  echo "Issuing command = curl $1/health | jq -c '[. | {status: .status}]' | grep \"UP\""

 waitcount=1
 while [ $waitcount -le 300 ]
  do
    sleep 1 
    up=`curl $1/health | jq -c '[. | {status: .status}]' | grep "UP"`
    echo "up = $up"
    if [[ -z $up ]]; then
       waitcount=$(( $waitcount + 1 ))
    else
       waitcount=301
    fi
  done
  if [[ -z $up ]]; then
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
   for x in $serverStarted
    do
       url=`echo $x | grep http`
    done
    IFS=$oldIFS
}
###########################
# Clean up after run
#########################
cleanup() {

    if [ $1 -eq 0 ]; then
      cd /tmp
      rm -r $stack_loc
      echo "Test of stack completed Successfully!!!!"
    else
      echo "Test of stack failed!! Results can be found in $stack_loc"    
    fi
}
stopRun() {

   runId=`ps -ef | grep "appsody run" | grep -v grep`
   runId=`echo $runId | head -n1 | awk '{print $2;}'`
   echo "Stopping appsody runid $runId"
   kill $runId
}

#Check parameters
if [ "$#" -lt 2 ]; then
    echo "Illegal number of parameters"
    echo "Command syntax is test-stack.sh repositoryName stackName templateName"
    exit 12
fi
  appsodyNotInstalled=`appsody version | grep "command not found"`
  if [[ ! -z $appsodyNotInstalled ]]; then 
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
   cleanup 12
   exit 12
 fi
###########################
# do a run from this stack #
#t##########################
 appsody run -p 9444:9443  > run.log &
 
 waitMessage="Waiting for server to start"
 waitcount=1
 echo $waitMessage
 while [ $waitcount -le 300 ]
  do
    sleep 1
    waitcount=$(( $waitcount + 1 ))
    serverStarted=`cat run.log | grep "server is ready to run a smarter planet"`
    if [[ ! -z $serverStarted ]]; then
       waitcount=301
       echo "\nServer Has Started\n"
    else
       waitcount=$(( $waitcount + 1 ))
    fi
 done
 
 if [[ -z $serverStarted ]]; then 
   echo "Server has not successfully started in 6 minutes"
   echo  "\nTest Failed!!!!!!\n" 
   stopRun
   cleanup 12
   exit 12 
 fi 
 
 echo "Server has started" 
 healthURL="http://localhost:9080"
 checkHealthURL $healthURL
 failed=`echo $results | grep Failed!`
 if [[ ! -z $failed ]]; then
   stopRun
   cleanup 12
   exit 12
 fi

################
# Check app url
###############
 appURL="http://localhost:9080"
 checkAppURL $appURL
 up=`echo $result | grep Failed!`
 if [[ ! -z $up ]]; then
    stopRun
    cleanup 12
    exit 12
 fi

 stopRun

 echo "Issuing appsody deploy"
 appsody deploy > deploy.log 2>&1 
 #####################################
 # give the apps some time to start 
 #####################################
 sleep 15
 serverStarted=`tail deploy.log | grep "Deployed project running at "`

 if [[ -z $serverStarted ]]; then
   echo "Server failed to start  Test Failed!!!!!"
   appsody deploy delete
   cleanup 12
   exit 12
 fi
 getDeployedURL $serverStarted

 echo " "
 echo "*********************************"
 echo "       Kubernetes Deployments    "
 kubectl get all
 echo "*********************************"
 echo " "
 echo "Checking Health status with URL $url"
 echo " "
 checkHealthURL $url
 up=`echo $result | grep Failed!`
  if [[ ! -z $up ]]; then
    # appsody deploy delete
     cleanup 12
     exit 12
  fi 
 echo "Checking appsody deploy app with $url"
 checkAppURL $url
 up=`echo $result | grep Failed!`
 if [[ ! -z $up ]]; then
    echo  $up
    #appsody deploy delete
    cleanup 12
    exit 12
 fi
 
 #appsody deploy delete

 cleanup 0 
