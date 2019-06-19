#!/bin/bash

IMAGE_POOL_DIR=/var/lib/libvirt/images
IMAGE_FORMAT=qcow2
VM_NAME=$1
VM_RESIZE=18G
VM_RAM=4096
VM_CPU=2
VM_OS_TYPE=linux
VM_OS_VARIANT=ubuntu16.04
VM_NETWORK="bridge=br0"
VM_SEED_IMG=seed.img

RELEASE_NUMBER=${2:-$(lsb_release -sr)}
RELEASE_NAME=${3:-$(lsb_release -sc)}

DOWNLOAD_URL="https://cloud-images.ubuntu.com/minimal/releases/$RELEASE_NAME/release"
DOWNLOAD_FILENAME="ubuntu-$RELEASE_NUMBER-minimal-cloudimg-amd64.img"

if [ -z "$VM_NAME" ]; then
 echo "VM name required"
 exit -1
fi

if [ ! -f "$VM_SEED_IMG" ]; then
  echo "seed image $VM_SEED_IMG not found"
  exit -1
fi

if [[ $(virsh list --name --all | grep $VM_NAME ) != ""  ]] || [ -f "$IMAGE_POOL_DIR/$VM_NAME.qcow2" ]; then
 echo "VM or image with that name already exists"
 exit -1
fi

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

VM_IMAGE=$IMAGE_POOL_DIR/$VM_NAME.$IMAGE_FORMAT
sudo qemu-img convert -O $IMAGE_FORMAT $DOWNLOAD_FILENAME $VM_IMAGE
if [ $? -ne 0 ]; then
  echo "Unable to convert & install image"
  exit $?
else
  echo "Image converted & installed"
fi

sudo qemu-img resize $VM_IMAGE +$VM_RESIZE
if [ $? -ne 0 ]; then
  echo "Unable to resize image"
  exit $?
fi

VM_CMD="virt-install --noautoconsole --import --autostart --graphics none --os-type=$VM_OS_TYPE --os-variant=$VM_OS_VARIANT --network $VM_NETWORK --ram $VM_RAM --vcpu $VM_CPU --disk $VM_SEED_IMG,device=cdrom --disk $VM_IMAGE,device=disk,bus=virtio --name $VM_NAME"

$VM_CMD
if [ $? -ne 0 ]; then
  echo "Unable to create vm"
  exit $?
else
  echo "use 'virsh console $VM_NAME' to connect"
fi
