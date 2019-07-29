#!/bin/bash

echo "This porgram finds vms ip address and after that make ssh connection"
fedora_2_ip=`virsh net-dhcp-leases default | grep fedora-2 | awk '{print $5}' | cut -d/ -f1`
ssh vl@$fedora_2_ip
