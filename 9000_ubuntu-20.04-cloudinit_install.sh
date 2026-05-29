#!/bin/bash

set -eux

IMAGE_URL=https://ftp.udx.icscoe.jp/Linux/ubuntu-cloud-images/focal/current/focal-server-cloudimg-amd64.img
IMAGE_PATH=/var/lib/vz/template/iso/focal-server-cloudimg-amd64.img
VM_ID=9000
VM_NAME=ubuntu-20.04-cloudinit
BRIDGE=vmbr0
STORAGE=local-lvm
CICUSTOM_USER=local:snippets/${VM_ID}_ubuntu-20.04-cloudinit_user.yaml
CICUSTOM_META=local:snippets/${VM_ID}_ubuntu-20.04-cloudinit_meta.yaml

curl -sLo "$IMAGE_PATH" "$IMAGE_URL"

qemu-img resize "$IMAGE_PATH" 20G

virt-customize \
	-a "$IMAGE_PATH" \
	--run-command 'growpart /dev/sda 1' \
	--run-command 'resize2fs /dev/sda1' \
	--update \
	--install qemu-guest-agent \
	--run-command 'apt-get clean' \
	--run-command 'systemctl enable qemu-guest-agent' \
	--run-command 'truncate -s 0 /etc/machine-id' \
	--run-command 'rm -f /var/lib/dbus/machine-id' \
	--run-command 'rm -f /var/lib/systemd/random-seed'

qm create $VM_ID \
	--name $VM_NAME \
	--cpu "x86-64-v4,flags=+nested-virt" \
	--cores 1 \
	--memory 512 \
	--scsihw virtio-scsi-pci \
	--scsi0 "${STORAGE}:0,import-from=$IMAGE_PATH" \
	--ide2 "${STORAGE}:cloudinit" \
	--serial0 socket \
	--vga serial0 \
	--boot order=scsi0 \
	--net0 virtio,bridge="$BRIDGE" \
	--ipconfig0 ip=dhcp,ip6=auto \
	--nameserver "1.1.1.1 1.0.0.1" \
	--searchdomain "localhost" | sed 's/ -/\n\t-/g' \
	--agent enabled=1 \
	--cicustom "user=${CICUSTOM_USER},meta=${CICUSTOM_META}" \

qm template $VM_ID