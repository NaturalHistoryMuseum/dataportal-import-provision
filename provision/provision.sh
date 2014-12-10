#!/bin/bash

# Parameters
PROVISION_FILE=/etc/import-provisioned
PROVISION_COUNT=5 # Make sure to  update this when adding new updates!
PROVISION_FOLDER=
PROVISION_STEP=0

DEV_MODE=1
SYNCED_FOLDER=/vagrant
CKAN_URL=
API_KEY=

#
# usage() function to display script usage
#
function usage(){
  echo "Usage: $0 options

This script provisions a server to host the NHM data portal postgres
database. It will:
 - Install the mongo database and ke2mongo package and requirements;

OPTIONS:
  -h   Show this message
  -r   Path to folder containing provisioning resources.
       This defaults to the path of the current script,
       however when provisioning via Vagrant this might
       not be what you expect, so it is safer to set
       this.
  -x   Set the provision step to run. Note that running this WILL NOT
       UPDATE THE CURRENT PROVISION VERSION. Edit ${PROVISION_FILE}
       manually for this.

To run: sudo ./provision.sh -x 5

"
}

#
# Parse arguments
#
while getopts "hr:x:" OPTION; do
  case ${OPTION} in
    h)
      usage
      exit 0
      ;;
    r)
      PROVISION_FOLDER=${OPTARG}
      ;;
    x)
      PROVISION_STEP=${OPTARG}
      ;;
    ?)
      usage
      exit 1
      ;;
  esac
done

# Set the default provision folder
if [ "${PROVISION_FOLDER}" = "" ]; then
  PROVISION_FOLDER="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
fi

#
# pip_install_req function ; takes one parameter as a
# path to a requirements.txt file.
#
function pip_install_req(){
  RETURN_STATUS=0
  for i in {1..3}; do
    pip --timeout=30 --exists-action=i install -r $1
    RETURN_STATUS=$?
    [ ${RETURN_STATUS} -eq 0 ] && break
  done
  if [ ${RETURN_STATUS} -ne 0 ]; then
    echo "Failed installing requirements ; aborting" 1>&2
    exit 1
  fi
}


#
# Initial provision, step 1: install required packages
#
function provision_1(){
  # Install packages
  echo "Updating and installing packages"
  apt-get update
  apt-get install -y python-dev python-pip python-virtualenv python-pastescript build-essential git-core libicu-dev libyaml-perl
}

#
# Step 2; Install Mongo DB
#
function provision_2(){
  # Install mongodb
  echo "Installing Mongo DB"
  # We want latest version for the aggregate functions, so we need the 10 gen distro
  # Add key
  sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
  # Create list file
  echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' | sudo tee /etc/apt/sources.list.d/mongodb.list
  # Update packages
  sudo apt-get update
  # And install
  sudo apt-get install -y mongodb-org
}

#
# Step 3; Install virtual env and pip libs
#
function provision_3(){

  # Symlinks (Development only)
  if [ ${DEV_MODE} -eq 1 ]; then
    echo "Setting up symlinks"
    mkdir -p "${SYNCED_FOLDER}/lib"
    ln -sf "${SYNCED_FOLDER}/lib" /usr/lib/import
  fi

  # Create virtual env
  echo "Creating virtual environment"
  mkdir -p /usr/lib/import
  virtualenv /usr/lib/import

}

#
# Initial provision, step 4: Install KE2Mongo extension and requirements.
#
function provision_4(){
  if [ ! -f "${PROVISION_FOLDER}/client.cfg" ]; then
    echo "Missing file ${PROVISION_FOLDER}/client.cfg ; aborting." 1>&2
    exit 1
  fi

  cd /usr/lib/import
  . /usr/lib/import/bin/activate

  pip install -e 'git+https://github.com/NaturalHistoryMuseum/ke2mongo.git#egg=ke2mongo'

  if [ $? -ne 0 ]; then
    echo "Failed installing ke2mongo ; aborting" 1>&2
    exit 1
  fi

  echo "Install KE2Mongo requirements"
  pip_install_req /usr/lib/import/src/ke2mongo/requirements.txt
}

#
# Initial provision, step 5: Update and copy across the KE EMu config file
#
function provision_5(){

  echo "Updating and installing client.cfg"

  if [ ! -f "${PROVISION_FOLDER}/client.cfg" ]; then
    echo "Missing file ${PROVISION_FOLDER}/client.cfg ; aborting." 1>&2
    exit 1
  fi

 cat "$PROVISION_FOLDER/client.cfg" | sed -e "s~%CKAN_URL%~$CKAN_URL~"  -e "s~%API_KEY%~$API_KEY~" > /usr/lib/import/src/ke2mongo/ke2mongo/client.cfg
}

#
# Initial provision, step 7: Set up logging
#
function provision_6(){
  echo "Setting up logs"
  sudo chmod 0777 /var/log
}


#
# Work out current version and apply the appropriate provisioning script.
# Note that this script has 5 initial steps, rather than 1.
#
if [ ! -f ${PROVISION_FILE} ]; then
  PROVISION_VERSION=0
else
  PROVISION_VERSION=`cat ${PROVISION_FILE}`
fi
if [ "${PROVISION_STEP}" -ne 0 ]; then
  eval "provision_${PROVISION_STEP}"
elif [ "${PROVISION_VERSION}" -eq 0 ]; then
  provision_1
  provision_2
  provision_3
  provision_4
  provision_5
  provision_6
  echo ${PROVISION_COUNT} > ${PROVISION_FILE}
elif [ ${PROVISION_VERSION} -ge ${PROVISION_COUNT} ]; then
  echo "Server already provisioned"
else
  for ((PROV_INC=`expr ${PROVISION_VERSION}+1`; PROV_INC<=${PROVISION_COUNT}; PROV_INC++)); do
    echo "Running provision ${PROV_INC}"
    eval "provision_${PROV_INC}"
    echo ${PROV_INC} > ${PROVISION_FILE}
  done
fi
exit 0