# Functions
#
# @author Nestor Urquiza
#
# Runs remote commands using sudo. Password is provided in a variable
#
function runremote {
  user=$1
  host=$2
  password=$3
  command=$4
  
  expect -c "
  spawn ssh -t $user@$host \"sudo -k; sudo $command\"
  expect \"assword\"
  send \"$password\n\"
  interact
  catch wait reason
  set exit_code [lindex \$reason 3]
  if { \$exit_code > 0 } {
  	puts \"ERROR: exiting expect with \$exit_code\"
  	exit \$exit_code
  }
  "
}

#
# just rsync-ing
#
function rsyncFile {
  from=$1
  rsync -avz --delete -e "ssh -i $HOME/.ssh/id_rsa" $from $user@$host:~/
}
