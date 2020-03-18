#!/bin/bash

#################################
# Test script for testing appsody stacks
# Will either init a new project from a stack
# or clone a git repository containing one or more appsody
# projects initialized from a stack. 
# in either case an appsody run and an appsody deploy
# are run against the stack. The application's URL is
# then tested along with the heath URL provided by MP Metrics 
# if they can be accessed and provide correct results
# the test's pass.
##################################

#######################
# Check Application URL
#######################

checkAppURL() {
 if [[ $CONTEXT_ROOT != "NONE" ]]; then
   if [[ -z $CONTEXT_ROOT ]]; then
      CONTEXT_ROOT="/starter/resource"
   fi
   echo "Checking app URL with $1$CONTEXT_ROOT"
   waitcount=1
   while [ $waitcount -le 300 ]
   do
    sleep 1
    up=`curl --dump-header - $1$CONTEXT_ROOT | grep "200 OK"`
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
    echo " "
    echo $result
    echo " "
  else 
    echo "Application context set to none, skipping application URL test"
  fi
}
######################
# Check health url
#####################
checkHealthURL() {

 echo "Checking Health with URL $1/health" 
 echo "TEST_HEALTH=$TEST_HEALTH"
 if [[ $TEST_HEALTH == "Y" ]]; then
   waitcount=1
   while [ $waitcount -le 300 ]
    do
      sleep 1 
      up=`curl $1/health | jq -c '[. | {status: .status}]' | grep "UP"`
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
    echo " "
    echo $result
    echo " "
 else
    echo "--testHealth set to $TEST_HEALTH, Skipping health check"
 fi
}

#####################
# Get URL and port of
# app deployed to kubernetes
####################
getDeployedURL() {
   oldIFS=$IFS
   IFS=' '
   echo
   for x in $serverStarted
    do
       url=`echo $x | grep http`
       # on linux localhost is dropped from the URL so we need to 
       # put it back.
       port=`echo $url | awk '{split($0,a,":"); print  a[3]}'`
       url="http://localhost:$port"
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
      echo "Test of STACK failed!! Results can be found in $STACK_loc"    
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
   sleep 5
   buildSuccess=`cat run.log | grep "BUILD SUCCESS"`
   if [[ -z buildSuccess ]]; then
       echo "Tests did not sucessfully complete test Failed!!!!!"
   fi
}
#########################################
# Validate Parms are correct.
#########################################
checkParms() {
   # GIT repo parm takes precedence
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
  echo " The -t appsodyTemplate is optional and only applicable when using -a and -s "
  echo " "
  echo "Command syntax to test a git repository containing one or more Appsody Projects:"
  echo "test-stack.sh -g gitRepository -b branch"
  echo " -g gitRepository and -b branch are  mutually exclusive with the other arguments. "
  echo " -b branch is an optional and only applicable when using -g "
  echo " "
  echo " If a combination of mutually exclusive options are provided the -g and -b options will "
  echo " take precedence and the other options will be ignored "
  echo " "
  echo " The option -c contextRoot is available for all options it specifies the context root for the "
  echo " application URL that will be tested. If not specified a default value of /starter/resource will be used"
  echo " " 
  echo " The option -h healthcheck is available for all options it specifies if the microprofile health URL should be"
  echo " tested. This defaults to true if not specified. It will be false if any value other than Y is provided."
  echo " "
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
     else
        waitcount=$(( $waitcount + 1 ))
     fi
  done
 
  if [[ -z $serverStarted ]]; then
    echo "Server has not successfully started in 6 minutes"
    echo " "
    echo "Test Failed!!!!!!"
    echo " "
    stopRun
    cleanup 12
    exit 12
  fi

  echo "Server has started" 
  healthURL="http://localhost:9080"
  checkHealthURL $healthURL
  failed=`echo $result | grep "Failed!"`
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

doDeploy() {
    echo "Issuing appsody deploy"
    appsody deploy > deploy.log 2>&1
    #####################################
    # give the apps some time to start
    #####################################
    sleep 30
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
    echo "*********************************"
    kubectl get all
    echo "*********************************"
    echo " "
    echo " "
    checkHealthURL $url
    up=`echo $result | grep Failed!`
     if [[ ! -z $up ]]; then
        appsody deploy delete
        cleanup 12
        exit 12
     fi
    checkAppURL $url
    up=`echo $result | grep Failed!`
    if [[ ! -z $up ]]; then
       appsody deploy delete
       cleanup 12
       exit 12
    fi
 
    appsody deploy delete
}
#############
## Main
############


TEMPLATE=""
GIT_REPO=""
BRANCH=""
CONTEXT_ROOT=""
STACK=""
APPSODY_REPO=""
TEST_HEALTH="Y"

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
    -b|--branch)
    BRANCH="$2"
    shift # past argument
    shift # past value
    ;;
    -c|--contextRoot)
    CONTEXT_ROOT="$2"
    shift # past argument
    shift # past value
    ;;
    -h|--health)
    TEST_HEALTH="$2"
    shift # past argument
    shift # past value
    ;;
    *)    # unknown option
    invalidArgs
    exit 12
    ;;
esac
done

echo "git repo     = $GIT_REPO"
echo "branch       = $BRANCH"
echo "appsody repo = $APPSODY_REPO"
echo "stack        = $STACK"
echo "template     = $TEMPLATE"
echo "context root = $CONTEXT_ROOT"

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
    if [[ -z $BRANCH ]]; then
      gitCloneResults=`git clone $GIT_REPO`
    else
      gitCloneResults=`git clone --single-branch --branch $BRANCH $GIT_REPO` 
    fi
    STACK_loc=`echo $GIT_REPO |  awk '{split($0,a,"/"); print a[2]}' | awk '{split($0,a,".git"); print a[1]}'`
    if [[ -z $STACK_loc ]] || [[ ! -d $STACK_loc ]]; then
      echo "Failure creating git repo: $gitCloneResults"
      exit 12
    fi
    cd $STACK_loc
    appsodyProjects=`find ./ -name .appsody-config.yaml`
    if [ ! -z $appsodyProjects ]; then
     for project in $appsodyProjects
      do
        appsodyConfig=.appsody-config.yaml
        project=`echo $project | awk '{split($0,a,".//"); print a[2]}' | awk '{split($0,a,"/$appsodyConfig"); print a[1]}'`   
        if [[ $project != $appsodyConfig ]]; then
           cd $project
        fi
        project_loc=`pwd`
        echo "Appsody run for project at $project_loc"
        if [[ ! -f ".appsody-nodev" ]]; then
          doRun
          stopRun
          doDeploy
        else 
          echo "$project is a binary project run will be skipped"
          doDeploy
        fi
        cd - 
      done
    else
        echo "ERROR: no appsody  projects in repo"
        cleanup 12
        exit 12 
    fi
 else
   repoExists=`appsody repo list | grep $APPSODY_REPO`
   if [[ ! $repoExists ]]; then
     echo "repo $APPSODY_REPO is not available, please select a valid repository"
     exit 12
   fi
 
   STACKInRepo=`appsody list | grep $STACK | grep $APPSODY_REPO`
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
   appsody init $APPSODY_REPO/$STACK $TEMPLATE
   if [[ $? -ne 0 ]]; then
     echo "An error has occurred initializing the STACK, rc=$?"
     cleanup 12
     exit 12
   fi

   doRun
   stopRun
   doDeploy 
 fi
 cleanup 0 
