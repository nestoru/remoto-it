#!/bin/bash -e
#
# name: build-vm.sh
# author: Nestor Urquiza
# date: 20120529
#
# Tested in OSX
#
# To create a VirtualBox Ubuntu dev environment look into http://thinkinginsoftware.blogspot.com/2012/05/building-and-sharing-virtualbox-vm-for.html
#

START=$(date +%s)

USAGE="Usage: `basename $0` <OS TYPE> <ISO PATH/VDI PATH> <VM NAME> <HDD SIZE> (`basename $0` Ubuntu_64 ~/Downloads/bhubdev.vdi  bhubdev 20000)"

OS_TYPE=$1
IMG_PATH=$2
UUID=$3
HDD_SIZE=$4
VDI_PATH="$HOME/VirtualBox VMs/$UUID/$UUID.vdi"

#Main
if [ $# -ne "4" ] 
then
 echo $USAGE
    exit 1 
fi

if [[ ! "$IMG_PATH" == *.iso* && ! "$IMG_PATH" == *.vdi* ]]
then
 echo $USAGE
    exit 1
fi

echo "WARNING: You have provided an Image path. Are you sure you want to delete VM '$UUID'. This action cannot be rolled back!!! (y/n)"
read response
if [ "$response" != "y" ]
 then
 echo "Nothing to be done. You can provide a vdi path instead if you like"
 exit 0
fi 

VBoxManage list vms | grep $UUID && VBoxManage unregistervm $UUID --delete
VBoxManage list vms | grep $UUID || VBoxManage createvm --name "$UUID" --ostype $OS_TYPE --register
 
if [[ "$IMG_PATH" == *.iso* ]]
then
 VBoxManage createhd --filename "$VDI_PATH" --size $HDD_SIZE
fi

if [[ "$IMG_PATH" == *.vdi* ]]
then
 rsync -avz "$IMG_PATH" "$VDI_PATH"
fi

VBoxManage internalcommands sethduuid "$VDI_PATH"

VBoxManage list hostonlyifs | grep -q vboxnet0 || VBoxManage hostonlyif create 
VBoxManage modifyvm "$UUID" --hostonlyadapter2 vboxnet0
VBoxManage hostonlyif ipconfig vboxnet0 --ip 192.168.56.1 
VBoxManage modifyvm "$UUID" --memory 1024 --acpi on --boot1 dvd --nic1 nat --nic2 hostonly
VBoxManage showvminfo "$UUID" | grep "SATA Controller" || VBoxManage storagectl "$UUID" --name "SATA Controller" --add sata --controller IntelAhci
VBoxManage storageattach "$UUID" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$VDI_PATH"
if [[ "$IMG_PATH" == *.iso* ]]
then
 VBoxManage storageattach "$UUID" --storagectl "SATA Controller" --port 1 --device 0 --type DVDDRIVE --medium "$IMG_PATH"
 echo "Continue with any customizations for the VDI. When done shutdown the guest (i.e sudo shutdown -h now) so this scripts finishes normally."
 VBoxManage startvm "$UUID"
 sleep 3
 echo "Login now into the VM. After the installation is finished come back here and press enter to gracefully finish this script"
 read anything
 VBoxManage storageattach "$UUID" --storagectl "SATA Controller" --port 1 --device 0 --type dvddrive --medium none
fi

END=$(date +%s)
DIFF=$(( $END - $START ))
date
echo "Finished in $DIFF seconds"
