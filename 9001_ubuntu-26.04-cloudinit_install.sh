#!/bin/bash

set -eux

IMAGE_URL=https://ftp.udx.icscoe.jp/Linux/ubuntu-cloud-images/resolute/current/resolute-server-cloudimg-amd64.img
IMAGE_DIR=/var/lib/vz/template/iso
IMAGE_NAME=resolute-server-cloudimg-amd64.img
VM_ID=9001
VM_NAME=ubuntu-26.04-cloudinit
BRIDGE=vmbr0
STORAGE=local-lvm
CICUSTOM_USER=local:snippets/${VM_ID}_ubuntu-26.04-cloudinit_user.yaml
CICUSTOM_META=local:snippets/${VM_ID}_ubuntu-26.04-cloudinit_meta.yaml

curl -sLo "$IMAGE_DIR/$IMAGE_NAME" "$IMAGE_URL"

FORMAT=$(qemu-img info "$IMAGE_DIR/$IMAGE_NAME" | awk -F': ' '/file format:/ {print $2}')
IMAGE_TMP=$IMAGE_DIR/$IMAGE_NAME.tmp
qemu-img create -f $FORMAT $IMAGE_TMP 20G
virt-resize --expand /dev/sda1 $IMAGE_DIR/$IMAGE_NAME $IMAGE_TMP
mv $IMAGE_TMP $IMAGE_DIR/$IMAGE_NAME

virt-customize \
	-a "$IMAGE_DIR/$IMAGE_NAME" \
	--update \
	--install qemu-guest-agent \
	--run-command 'apt-get clean' \
	--run-command 'systemctl enable qemu-guest-agent'

qm create $VM_ID \
	--name $VM_NAME \
	--memory 512 \
	--cores 1 \
	--cpu "x86-64-v4,flags=+nested-virt" \
	--net0 virtio,bridge="$BRIDGE" \
	--scsihw virtio-scsi-pci \
	--agent enabled=1 \
	--scsi0 "local-lvm:0,import-from=$IMAGE_DIR/$IMAGE_NAME" \
	--ide2 "local-lvm:cloudinit" \
	--serial0 socket --vga serial0 \
	--boot order=scsi0

qm resize $VM_ID scsi0 20G

qm template $VM_ID

qm set $VM_ID \
	--cicustom "user=${CICUSTOM_USER},meta=${CICUSTOM_META}" \
	--ipconfig0 ip=dhcp,ip6=auto \
	--nameserver "1.1.1.1 1.0.0.1" \
	--searchdomain "localhost" | sed 's/ -/\n\t-/g'
