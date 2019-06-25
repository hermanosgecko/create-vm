#!/bin/bash
# vim: set ts=4:
#---help---
# Usage: create-vm [options] [--] <name> [<seed-image>]
#
# This script creates an ubuntu vm
#
# Arguments:
#   <name>				Name of the virtual machine to create
#
#   <seed-image>			Name of the cloud-init seed image to use
#
# Options and Environment Variables:
#      --release-name		Ubuntu release name to use. 
#				Default is "bionic".
#
#      --release-number		Ubuntu release number to use. 
#				Default is "18.04".
#
#      --image-pool		Libvirt image pool to use. 
#				Default is /var/lib/libvirt/images.
#
#      --resize-img		Resize the disk image to create
#				in bytes or with suffix
#				(e.g. 1G, 1024M).
#
#      --image-format		Format of the disk image 
#				(see qemu-img --help). 
#				Default is qcow2.
#
#      --ram 			Amount of ram for the vm to have. 
#				Default is 4096MB.
#
#      --cpu 			Amount of cpu for the vm to have. 
#				Default is 2.
#
#      --bridge			Network bridge for the vm to use. 
#
#   -h --help			Show this help message and exit.
#
#   -v --version			Print version and exit.
#
#
#
# https://github.com/hermanosgecko/create-vm
#---help---

readonly PROGNAME='create-vm'
readonly VERSION='v0.1'

# Prints help and exists with the specified status.
help() {
	sed -En '/^#---help---/,/^#---help---/p' "$0" | sed -E 's/^# ?//; 1d;$d;'
	exit ${1:-0}
}

#=============================  M a i n  ==============================#
opts=$(getopt -n $PROGNAME -o h:v \
	-l release-name:,release-number:,image-pool,resize-img:,image-format:,ram:,cpu:,bridge:,help,version \
	-- "$@") || help 1 >&2

eval set -- "$opts"
while [ $# -gt 0 ]; do
	n=2
	case "$1" in
		     --release-name) RELEASE_NAME="$2";;
		     --release-number) RELEASE_NUMBER="$2";;
		     --image-pool) IMAGE_POOL_DIR="$2";;
		     --resize-img) IMAGE_RESIZE="$2";;
		     --image-format) IMAGE_FORMAT="$2";;
		     --ram) VM_RAM="$2";;
		     --cpu) VM_CPU="$2";;
		     --bridge) VM_BRIDGE="$2";;
		-h | --help) help 0;;
		-V | --version) echo "$PROGNAME $VERSION"; exit 0;;
		--) shift; break;;
	esac
	shift $n
done

: ${RELEASE_NAME:="bionic"}
: ${RELEASE_NUMBER:="18.04"}
: ${IMAGE_POOL_DIR:="/var/lib/libvirt/images"}
: ${IMAGE_FORMAT:="qcow2"}
: ${VM_RAM:="4096"}
: ${VM_CPU:="2"}
: ${VM_OS_TYPE:="linux"}
: ${VM_OS_VARIANT:="ubuntu18.04"}

[ $# -ne 0 ] || help 1 >&2

VM_NAME="$1"; shift

SEED_IMG=
[ $# -eq 0 ] || { SEED_IMG="$1"; shift; }

VM_NETWORK="bridge=br0"

if [ -z "$VM_NAME" ]; then
 echo "Virtual machine name required"
 exit -1
fi

if [[ $(virsh list --name --all | grep $VM_NAME ) != ""  ]] || [ -f "$IMAGE_POOL_DIR/$VM_NAME.qcow2" ]; then
 echo "VM or image with that name already exists"
 exit -1
fi

DOWNLOAD_URL="https://cloud-images.ubuntu.com/minimal/releases/$RELEASE_NAME/release"
DOWNLOAD_FILENAME="ubuntu-$RELEASE_NUMBER-minimal-cloudimg-amd64.img"
if [ ! -f "$DOWNLOAD_FILENAME" ]; then
  echo "Downloading image"
  wget $DOWNLOAD_URL/$DOWNLOAD_FILENAME -o "$DOWNLOAD_FILENAME.log"
  if [ $? -ne 0 ]; then
    echo "Unable to download image, see $DOWNLOAD_FILENAME.log"
    exit $?
  else
    rm "$DOWNLOAD_FILENAME.log"
  fi
else
  echo "Image already downloaded"
fi

VM_IMAGE=$VM_NAME.$IMAGE_FORMAT
qemu-img convert -O $IMAGE_FORMAT $DOWNLOAD_FILENAME $VM_IMAGE
if [ $? -ne 0 ]; then
  echo "Unable to convert & install image"
  exit $?
else
  echo "Image converted & installed"
fi

if [ -z IMAGE_RESIZE ]; then
   qemu-img resize $VM_IMAGE +$IMAGE_RESIZE
   if [ $? -ne 0 ]; then
     echo "Unable to resize image"
     exit $?
   fi
fi

mv $VM_IMAGE $IMAGE_POOL_DIR

VM_CMD="virt-install --noautoconsole --import --autostart --graphics none --os-type=$VM_OS_TYPE --os-variant=$VM_OS_VARIANT --ram $VM_RAM --vcpu $VM_CPU --disk $IMAGE_POOL_DIR/$VM_IMAGE,device=disk,bus=virtio --name $VM_NAME"

if [ ! -z "$VM_BRIDGE" ]; then
   VM_CMD="${VM_CMD} --network bridge=$VM_BRIDGE"
fi

if [ ! -z "$SEED_IMG" ]; then
   VM_CMD="${VM_CMD} --disk $SEED_IMG,device=cdrom"
fi

$VM_CMD
if [ $? -ne 0 ]; then
  echo "Unable to create vm"
  exit $?
else
  echo "use 'virsh console $VM_NAME' to connect"
fi
