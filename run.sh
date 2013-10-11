#!/bin/bash -ex
#
# remoto-it/run.sh
#
# @author Nestor Urquiza
#
# Preconditions: A public key from the local server must be authorized in the remote server. Usually you should be able to:
#                ssh-copy-id -i ~/.ssh/id_rsa.pub user@remote.domain.com
#
# 
# Provisions remote servers following conventions and/or configuration: 
# Once logged in the remote server it uses 'sudo' to obtain root access. All commands are then run as root. Do not use sudo in recipes.
# Either a list of bash scripts (recipes) is expected per server with name recipes/${hostname} or an optional recipe path.
# Several servers can be managed in one invocation if a file holding a line per remote server is used instead of a single host. 
# Using rsync it transfers and run as root all listed recipes in the remote server using a password it stores after prompting the user 
# 

START=$(date +%s)

NO_ARGS=0
USAGE="Usage: `basename $0` <user> <host | hostNamesFilePath> [recipeFilePath]"

#Main
if [ $# -lt "2" ] 
then
    echo $USAGE
    exit 1 
fi

user=$1
hostOrHosts=$2
recipeFilePath=$3
hosts[0]=$hostOrHosts

hostsInFile=false;
if [[ $hostOrHosts =~ ^.*\/.* ]]; then
    hostsInFile=true;
fi

source ./common.sh

echo -n "$user Password: "
read -s password
echo

export user
export password

old_IFS=$IFS
IFS=$'\n'
if $hostsInFile; then
 hosts=($(cat ${hostOrHosts}))
fi
for host in "${hosts[@]}"
do
	export host
	if [ "$recipeFilePath" ]; then
		lines=($(cat $recipeFilePath))
	else
    	lines=($(cat ../recipes/${host}.sh))
	fi
    #rsync the whole recipes directory
    runremote $user $host $password "chown -R $user ~/recipes/"
    rsyncFile ../recipes/
    for recipe in "${lines[@]}"
    do
     if [[ $recipe =~ ^[0-9a-zA-Z].* ]]
     then
        echo "************* Running: $recipe ***************"
        #remotely run as root the corresponding config script
        runremote $user $host $password "$recipe"
      fi
    done
done
IFS=$old_IFS

END=$(date +%s)
DIFF=$(( $END - $START ))
date
echo "SUCCESS: Finished in $DIFF seconds"
