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
 if [[ $URL_PATH != "NONE" ]]; then
   if [[ -z $URL_PATH ]]; then
      URL_PATH="/starter/resource"
   fi
   echo "Checking app URL with $1$URL_PATH"
   waitcount=1
   while [ $waitcount -le 300 ]
   do
    sleep 1
    up=`curl --dump-header - $1$URL_PATH | grep "200 OK"`
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

#########################################
# Docker run is started in the background
# use this to stop the runing container 
#########################################
stopDockerRun() {
    echo "Stopping docker run for container $1"
    docker container stop $1
    if [[ $? != 0 ]]; then
        echo "Error attempting to stop docker container $1"
    fi
    #docker container rm $1
    #if [[ $? != 0 ]]; then
    #   echo "Error removing container $1"
    #fi
}

##########################################
# Appsody run is started in the background
# Use this to find the process and stop it
##########################################
stopAppsodyRun() {
   #runId=`ps -ef | grep -P "appsody$" | grep -v grep`
   #runId=`echo $runId | head -n1 | awk '{print $2;}'`
   dockerPS
   lastContainerId=$(docker ps -lq)
   echo "Stopping Docker container: $lastContainerId"
   docker stop $lastContainerId
   echo "Stopped"
   dockerPS
   sleep 3
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
  echo "test-project.sh -a appsodyRepo -s appsodyStack -t appsodyTemplate"
  echo " The -t appsodyTemplate is optional and only applicable when using -a and -s "
  echo " "
  echo "Command syntax to test a git repository containing one or more Appsody Projects:"
  echo "test-project.sh -g gitRepository -b branch"
  echo " -g gitRepository and -b branch are  mutually exclusive with the other arguments. "
  echo " -b branch is an optional and only applicable when using -g "
  echo " "
  echo " If a combination of mutually exclusive options are provided the -g and -b options will "
  echo " take precedence and the other options will be ignored "
  echo " "
  echo " The option -p path is available for all options it specifies the URL path for the "
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
  appsody run -p $HTTPS_HOST_PORT:$HTTPS_PORT  > run.log &
 
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
    stopAppsodyRun
    cleanup 12
    exit 12
  fi

  echo "Server has started" 
  healthURL="http://localhost:$HTTP_PORT"
  checkHealthURL $healthURL
  failed=`echo $result | grep "Failed!"`
  if [[ ! -z $failed ]]; then
    stopAppsodyRun 
    cleanup 12
    exit 12
  fi
 
 ################
 # Check app url
 ###############
  appURL="http://localhost:$HTTP_PORT"
  checkAppURL $appURL
  up=`echo $result | grep Failed!`
  if [[ ! -z $up ]]; then
     stopAppsodyRun 
     cleanup 12
     exit 12
  fi
}

doTest() {
 ###########################
 # do a test from this STACK #
 ############################
  appsody test -p $HTTPS_HOST_PORT:$HTTPS_PORT  > test.log 
  success=`cat test.log | grep "BUILD SUCCESS"`
  if [[ -z $success ]]; then
    cleanup 12
    exit 12
  fi

}
#############################
# Print debugging
############################
dockerPS() {
     # Spit out docker ps for possible collisions
     echo
     echo "WARNING: Since running containers may conflict with test, we will list any below.  (TODO: detect)"
     echo
     docker ps
     echo
     echo "=================================================="
     echo
}

#############################
# Run this instead of doDeploy
# Will do an appsody build then 
# Docker run with the resulting image
# More stable on Linux and Mac
############################
doBuildandRun() {
    echo "Doing Appsody  build and Docker run"
    appsody build > build.log
    if [[ $? != 0 ]]; then
      echo "Error executing appsody build "
      cleanup 12
      exit 12 
    fi
    dockerImage=`cat build.log | grep "Built docker image" | awk '{print $NF}'`
    echo "Running docker image $dockerImage"
    if [[ -z $dockerImage ]]; then
      echo "Docker image $dockerImage not found... exiting"
      cleanup 12 
      exit 12
    else
      # cleanup container.. or if it's helpful for debugging let's find another way
      docker container run --rm --name $1br -d -p $HTTP_PORT:$HTTP_PORT -p $HTTPS_HOST_PORT:$HTTPS_PORT $dockerImage
      if [[ $? != 0 ]]; then
        echo "Error issuing docker container run.. Test Failed!!!!!"
        stopDockerRun $1br
        cleanup 12 
        exit 12
      else
        healthURL="http://localhost:$HTTP_PORT"
        checkHealthURL $healthURL
        failed=`echo $result | grep "Failed!"`
        if [[ ! -z $failed ]]; then 
          stopDockerRun $1br
          cleanup 12 
          exit 12 
        fi
        appURL="http://localhost:$HTTP_PORT"
        checkAppURL $appURL
        up=`echo $result | grep Failed!`
        if [[ ! -z $up ]]; then 
           stopDockerRun $1br 
           cleanup 12
           exit 12 
        else
           stopDockerRun $1br
           cleanup 0 
        fi
      fi
    fi
}

####################################
# Not currently being called. 
# This does not work in a linux environment
# Saving it because it does work on a Mac
# May resurect later
###################################
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
URL_PATH=""
STACK=""
APPSODY_REPO=""
TEST_HEALTH="Y"
HTTP_PORT="9080"
HTTPS_PORT="9443"
HTTPS_HOST_PORT="9444"

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
    -p|--path)
    URL_PATH="$2"
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
echo "URL path     = $URL_PATH"

checkParms

appsodyNotInstalled=`appsody version | grep "command not found"`

if [[ ! -z $appsodyNotInstalled ]]; then 
  echo "appsody is not installed Please install appsody and try again"
  exit 12
fi 
 dockerPS

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
        ########### Debug #######
        echo "current project = $project"
        
        appsodyConfig=.appsody-config.yaml
        projectLoc=`echo $project | awk '{split($0,a,".//"); print a[2]}' | awk '{split($0,a,"/$appsodyConfig"); print a[1]}'`   
        if [[ ! -z $projectLoc ]] && [[ $projectLoc != $appsodyConfig ]]; then
           cd $projectLoc
        fi
        project_loc=`pwd`
        baseName=`basename $project_loc`
        echo "Appsody tsting project at $project_loc"
        echo "Project base name = $baseName"
        if [[ ! -f ".appsody-nodev" ]]; then
          doRun
          stopAppsodyRun
          doTest
          #doDeploy
	  if [[ $URL_PATH=="/starter/resource" ]]; then
            doBuildandRun $baseName
          else
            doBuildandRun $URL_PATH
          fi
        else 
          echo "$project is a binary project run will be skipped"
          #doDeploy
          if [[ $URL_PATH=="/starter/resource" ]]; then 
             doBuildandRun $baseName
          else 
             doBuildAndRun $URL_PATH
          fi
        fi
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

   STACK_loc=test-$STACK
   mkdir $STACK_loc
   if [[ $? -ne 0 ]]; then
     echo "unable to create location to install STACK, exiting"
     exit 12
   fi

   cd $STACK_loc
   if [[ $? -ne 0 ]]; then
     echo "unable to cd to STACK install directory /tmp/$STACK_loc, exiting"
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
   stopAppsodyRun
   doTest
   if [[ $URL_PATH=="/starter/resource" ]]; then
     doBuildandRun $STACK_loc
   else
     doBuildandRun $URL_PATH
   fi
 fi
