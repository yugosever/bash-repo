#!/bin/bash

fedora_3_ip=`virsh net-dhcp-leases default | grep fedora-3 | awk '{print $5}' | cut -d/ -f1`
ssh vl@$fedora_3_ip

