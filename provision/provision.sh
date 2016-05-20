#!/bin/bash

# Parameters
PROVISION_FILE=/etc/import-provisioned
PROVISION_COUNT=9 # Make sure to update this when adding new updates!
PROVISION_FOLDER=
PROVISION_STEP=0

DEV_MODE=1
SYNCED_FOLDER=/vagrant
CKAN_URL=127.0.0.1:8000
API_KEY=


LUIGI_ERROR_EMAIL=
LUIGI_EMAIL_SENDER=
LUIGI_SMTP_HOST=

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
# Initial provision, step 1: install required packages
#
function provision_1(){
  # Install packages
  echo "Updating and installing packages"
  apt-get update
  apt-get install -y python-pip python-virtualenv python-dev python-pastescript build-essential git-core libicu-dev libyaml-perl supervisor pkg-config libssl-dev libsasl2-dev make mercurial
}


# Step 3; Install virtual env and pip libs

function provision_2(){

    # Create virtual env
    echo "Creating virtual environment"
    mkdir -p "${SYNCED_FOLDER}/opt/import"
    virtualenv "${SYNCED_FOLDER}/opt/import"
    chown -R vagrant:vagrant "${SYNCED_FOLDER}/opt/import"
}

# Step 3; Install monary
function provision_3(){
    wget https://github.com/mongodb/mongo-c-driver/releases/download/1.3.0/mongo-c-driver-1.3.0.tar.gz -P /tmp
    cd /tmp/
    tar xzf mongo-c-driver-1.3.0.tar.gz
    cd mongo-c-driver-1.3.0
    ./configure --enable-sasl=yes --enable-ssl=yes
    make
    make install

    source "${SYNCED_FOLDER}/opt/import/bin/activate"

    hg clone https://@bitbucket.org/djcbeach/monary "${SYNCED_FOLDER}/opt/import/src/monary"
    cd "${SYNCED_FOLDER}/opt/import/src/monary"

    # Add trusted user
    echo -e "[trusted]\nusers = 1797455785\ngroups=vagrant" >> /etc/mercurial/hgrc

    # Note - this doesn't work with the latest version of monary (0.4.0 in pypi)
    hg pull && hg update monary-0.2.3
    python setup.py install

}

#
# Initial provision, step 5: Install KE2Mongo extension and requirements.
#
function provision_4(){
  if [ ! -f "${PROVISION_FOLDER}/client.cfg" ]; then
    echo "Missing file ${PROVISION_FOLDER}/client.cfg ; aborting." 1>&2
    exit 1
  fi
  cd "${SYNCED_FOLDER}/opt/import"
  pip install -e 'git+https://github.com/NaturalHistoryMuseum/ke2mongo.git#egg=ke2mongo'
  if [ $? -ne 0 ]; then
    echo "Failed installing ke2mongo ; aborting" 1>&2
    exit 1
  fi
  echo "Install KE2Mongo requirements"
  pip install -r "${SYNCED_FOLDER}/opt/import/src/ke2mongo/requirements.txt"
}

#
# Step 2; Install Mongo DB
#
function provision_5(){
  # Install mongodb
  echo "Installing Mongo DB"
  # We want latest version for the aggregate functions, so we need the 10 gen distro
  # Add key
  apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10
  # Create list file
  echo 'deb http://downloads-distro.mongodb.org/repo/ubuntu-upstart dist 10gen' | sudo tee /etc/apt/sources.list.d/mongodb.list
  # Update packages
  apt-get update
  # And install
  apt-get install -y mongodb-org
}


#
# Initial provision, step 6: Update and copy across the KE EMu and Luigi config files
#
function provision_6(){
  echo "Installing ke2mongo configuration file: config.cfg"
  if [ ! -f "${PROVISION_FOLDER}/config.cfg" ]; then
    echo "Missing file ${PROVISION_FOLDER}/config.cfg ; aborting." 1>&2
    exit 1
  fi

  cat "$PROVISION_FOLDER/config.cfg" | sed -e "s~%CKAN_URL%~$CKAN_URL~"  -e "s~%API_KEY%~$API_KEY~" > "${SYNCED_FOLDER}/opt/import/src/ke2mongo/ke2mongo/config.cfg"
  echo "Installing luigi configuration file: client.cfg"
  mkdir -p /etc/luigi
  if [ ! -f "${PROVISION_FOLDER}/client.cfg" ]; then
    echo "Missing file ${PROVISION_FOLDER}/client.cfg ; aborting." 1>&2
    exit 1
  fi
  cat "$PROVISION_FOLDER/client.cfg" | sed -e "s~%LUIGI_ERROR_EMAIL%~$LUIGI_ERROR_EMAIL~"  -e "s~%LUIGI_EMAIL_SENDER%~$LUIGI_EMAIL_SENDER~" -e "s~%LUIGI_SMTP_HOST%~$LUIGI_SMTP_HOST~" > /etc/luigi/client.cfg
}

#
# Initial provision, step 6: Set up logging
#
#function provision_7(){
#  echo "Setting up logs"
#  sudo chmod 0777 -R /var/log
#  mkdir /var/log/crontab
#  mkdir /var/log/tornado
#  mkdir /var/log/import
#}
#
#
#function provision_8(){
#   echo "Setting up tornado"
#   cp "$PROVISION_FOLDER/tornado-luigi.conf" /etc/supervisor/conf.d
#   sudo supervisorctl reread
#   sudo supervisorctl update
# }


#
# Initial provision, step 9: Set up bash login
#
function provision_9(){
  echo "Creating bash login $PROVISION_FOLDER"
  cat "${PROVISION_FOLDER}/.bash_login" | sed -e "s~%SYNCED_FOLDER%~$SYNCED_FOLDER~" > "/home/vagrant/.bash_login"
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
#  provision_1
#  provision_2
#  provision_3
#  provision_4
#  provision_5
#  provision_6
#  provision_7
#  provision_8
  provision_9

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