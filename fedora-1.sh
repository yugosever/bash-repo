#!/bin/bash

fedora_1_ip=`virsh net-dhcp-leases default | grep fedora-1 | awk '{print $5}' | cut -d/ -f1`
ssh vl@$fedora_1_ip
# git control
# git control 2
# git control 3
# git control 4
