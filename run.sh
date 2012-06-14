#!/bin/bash
#
# remoto-it/run.sh
#
# Preconditions: A public key from the local server must be authorized in the remote server. Usually you should be able to:
#                ssh-copy-id -i ~/.ssh/id_rsa.pub user@remote.domain.com
#
# 
# Provisions remote servers following conventions: 
# Once loged in the remote server it uses sudo to obtain root access. All commands are then run as root. Do not use sudo in recipes.
# A list of bash scripts (recipes) must exist per server with name recipes/${hostname}
# Using rsync it transfers and run as root all listed recipes in the remote server using a password it stores after prompting the user 
# 

START=$(date +%s)

set -e

NO_ARGS=0
USAGE="Usage: `basename $0` <user> <host>"

#Main
if [ $# -ne "2" ] 
then
	echo $USAGE
        exit 1 
fi

user=$1
host=$2


source ./common.sh

echo -n "$user Password: "
read -s password
echo

export user
export password
export host

old_IFS=$IFS
IFS=$'\n'
lines=($(cat ../recipes/${host}.sh)) # array
IFS=$old_IFS
for recipe in "${lines[@]}"
do
  if [[ $recipe =~ ^[0-9a-zA-Z].* ]]
  then
    echo "************* Running $recipe recipe ***************"
    firstDirOrFileToken=${recipe%%/*}
    rsyncFile ../recipes/$firstDirOrFileToken
    #remotely run as root the corresponding config script
    runremote $user $host $password "~/$recipe" yes
  fi
done


END=$(date +%s)
DIFF=$(( $END - $START ))
date
echo "Finished in $DIFF seconds"
