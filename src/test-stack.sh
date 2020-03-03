#!/bin/bash

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

#########################
# Clean up after run
#########################
cleanup() {

    if [ $1 -eq 0 ]; then
      cd /tmp
      chmod -R 777 $STACK_loc
      rm -r $STACK_loc
      echo "Test of STACK completed Successfully!!!!"
    else
      echo "Test of STACK failed!! Results can be found in $stack_loc"    
    fi
}


##########################################
# Appsody run is started in the background
# Use this to find the process and stop it
##########################################
stopRun() {

   runId=`ps -ef | grep "appsody run" | grep -v grep`
   runId=`echo $runId | head -n1 | awk '{print $2;}'`
   echo "Stopping appsody runid $runId"
   kill $runId
}
#########################################
# Validate Parms are correct.
#########################################
checkParms() {

   if [[ ! -z $GIT_REPO ]]; then
      APPSODY_REPO=""
      STACK=""
      TEMPLATE=""
   else
     if [[ -z  $APPSODY_REPO ]]; then
        echo "No Appsody repo passed "
        invalidArgs 
        exit 12
     fi
     if [[ -z $STACK ]]; then
        echo "No Stack provided "
        invalidArgs
        exit 12
     fi
   fi

}
###########################################
# Send message with command syntax when the
# wrong arguments are passed
##########################################
invalidArgs() {
  echo "Command syntax to initialize and test an appsody project:"
  echo "test-stack.sh -a appsodyRepo -s appsodyStack -t appsodyTemplate"
  echo " or to test a git repository containing one or more Appsody Projects:"
  echo "test-stack.sh -g gitRepository"
  echo " gitRepository is mutually exclusive with the other arguments. "
  echo " If a combination of both are specified the script will exit with an error"
  echo " appsodyTemplate is optional "
}

doRun() {
 ###########################
 # do a run from this STACK #
 ############################
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
}

#############
## Main
############


TEMPLATE=""
GIT_REPO=""

while [[ $# -gt 0 ]]
do
key="$1"
case $key in
    -g|--gitrepo)
    GIT_REPO="$2"
    shift # past argument
    shift # past value
    ;;
    -a|--appsody_repo)
    APPSODY_REPO="$2"
    shift # past argument
    shift # past value
    ;;
    -s|--stack)
    STACK="$2"
    shift # past argument
    shift # past value
    ;;
    -t|--template)
    TEMPLATE="$2"
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    invalidArgs
    exit 12
    ;;
esac
done

checkParms

appsodyNotInstalled=`appsody version | grep "command not found"`

if [[ ! -z $appsodyNotInstalled ]]; then 
  echo "appsody is not installed Please install appsody and try again"
  exit 12
fi 

 # create a location for the STACK to be initialized
 cd /tmp
 if [[ $? -ne 0 ]]; then
   echo "temp directory not avialable exiting "
   exit 12
 fi
 if [[ ! -z $GIT_REPO ]]; then
    gitInstalled=`git --version | grep version`
    if [[ -z $gitInstalled ]]; then
       echo "git is not installed on this server, Please install git and try again"
       exit 12
    fi
    gitCloneResults=`git clone $GIT_REPO`
    STACK_loc=`echo $GIT_REPO |  awk '{split($0,a,"/"); print a[2]}' | awk '{split($0,a,"."); print a[1]}'`
    if [[ -z $STACK_loc ]] || [[ ! -d $STACK_loc ]]; then
      echo "Failure creating git repo: $gitCloneResults"
      exit 12
    fi
    cd $STACK_loc
    appsodyProjects=`find ./ -name .appsody-config.yaml`
    for project in $appsodyProjects
     do
       project=`echo $project | awk '{split($0,a,".//"); print a[2]}' | awk '{split($0,a,"/.appsody-config.yaml"); print a[1]}'`   
       cd $project
       echo "Appsody run for project at $project"
       doRun
       stopRun
       cd - 
     done
 else

   repoExists=`appsody repo list | grep $repository`
   if [[ ! $repoExists ]]; then
     echo "repo $repository is not available, please select a valid repository"
     exit 12
   fi
 
   STACKInRepo=`appsody list | grep $stack | grep $repository`
   if [[ ! STACKInRepo ]]; then
      echo "Stack $STACK is not available in repo $repo. Please select valid stack"
      exit 12
   fi

   STACK_loc=test_$STACK
   mkdir $STACK_loc
   if [[ $? -ne 0 ]]; then
     echo "unable to create location to install STACK, exiting"
     exit 12
   fi

   cd $STACK_loc
   if [[ $? -ne 0 ]]; then
     echo "unable to cd to STACK install directory /tmp/$stack_loc, exiting"
     exit 12
   fi
   ######################### 
   # initialize the STACK  #
   ########################
   appsody init $repository/$STACK $TEMPLATE
   if [[ $? -ne 0 ]]; then
     echo "An error has occurred initializing the STACK, rc=$?"
     echo  "\nTest Failed!!!!!!\n"
     cleanup 12
     exit 12
   fi

   doRun
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
 
   appsody deploy delete
 fi
 cleanup 0 
