# Functions
#
# Runs remote commands using sudo. Password is provided in a variable
#
function runremote {
  user=$1
  host=$2
  password=$3
  command=$4
  asroot=${5:-"no"}
  
  expect -c "
  spawn ssh -t $user@$host \"sudo $command\"
  expect \"password\"
  send \"$password\n\"
  interact"

}

#
# just rsync-ing
#
function rsyncFile {
  from=$1
  rsync -avz --delete -e "ssh -i $HOME/.ssh/id_rsa" $from $user@$host:~/
}
