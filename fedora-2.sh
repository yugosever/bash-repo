#!/bin/bash

fedora_2_ip=`virsh net-dhcp-leases default | grep fedora-2 | awk '{print $5}' | cut -d/ -f1`
ssh vl@$fedora_2_ip
