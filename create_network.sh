#!/bin/bash

#create_xml_file
#check_domain_name
#check_if_network_already_exist
#define_network
#usage


usage(){
	echo "Usage: $0 [OPTION] ..."
	echo "Mandatory arguments"
	echo "-n, --network-name	Enter a new network name"
	echo
	echo "Optional arguments"
	echo "-m, --mac-address 	Enter a mac_addr, or random mac_addr will be specified"
	echo "-i, --ip-addr		Enter network ip_addr, or default will be specfied"
	echo "-s, --network-mask 	Enter network mask, or default /24 will be specified"
}


#Generat random mac_address
mac_addr=`cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 6 | head -n 1`
random_mac_addr=`echo "52:54:00:"${mac_addr:0:2}:${mac_addr:2:2}:${mac_addr:4:2}`

check_input_network_name(){
	if [ -z "$1" ]; then 
		echo "Netwok name should has at least one character"
		exit 1
	fi
	if [[ "$1" =~ ^[A-Za-z0-9]*$ ]];then
		return	
	else 
		echo "$1 is incorrect name"
		echo "Enter correct network name with alphanumeric symbols only"
		exit 1
	fi
}

check_if_network_already_exist(){
	check_names=`virsh net-list --all | grep $network_name | awk '{print $1}'`
	if [ -z $check_names ];then
		return
	elif [ $check_names = $1 ];then
		echo "network $network_name already exist, try specify new name"
		exit 1
	fi
}

check_input_mac_address(){
	if [[ $1 =~ ^([Ff]{2}:){5}[Ff]{2}$ ]];then
		echo "$1 is broadcast mac address. Try again..."
	fi
	if [[ $1 =~ ^([a-fA-F0-9]{2}:){5}[a-fA-F0-9]{2}$ ]]; then 
		return	
	else
		echo "Incorrect mac address $1 Try again..."
	fi	
}

check_if_mac_already_present(){
	names=`virsh list --all --name`
	for name in $names
        do 
		virsh domiflist $name | grep $1 &> /dev/null
		 if [ $? -eq 0 ];then 
			 echo $mac already present in $name
			 exit 1
		 fi 
	done
}

check_if_ip_in_private_range(){
	first_argument=$1
	if [ $first_argument -eq 10 ] || [ $first_argument -eq 172 ] || [ $first_argument -eq 192 ];then
		return
	else
		echo "$2 is not in private range"
		exit 1
	fi
}

check_input_ip_addr(){
	ip=$1
	if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]];then
		OIFS=$IFS
		IFS='.' ip_array=(${ip[*]}) 
		IFS=$OIFS
		if [ ${ip_array[0]} -gt 255 ] || [ ${ip_array[1]} -gt 255 ] || [ ${ip_array[2]} -gt 255 ] || [ ${ip_array[3]} -gt 255 ];then
			echo Bad ip_addr $ip
			exit 1
		fi
	fi
	if [ $ip = "255.255.255.255" ] || [ $ip = "0.0.0.0" ];then
		echo "Are you shure you want use this ip address? $ip" 
		exit 1
	fi
	check_if_ip_in_private_range ${ip_array[0]} $ip
}

check_input_network_mask(){
	if [ $1 -lt 8 ] || [ $1 -gt 30 ];then
		echo "You should specify valid network mask. Net_mask /$1 is incorrect. net_mask should be in 8-30 range"
		exit 1
	fi
}


create_define_new_network(){
	virsh net-define $network_name.xml
	virsh net-start $network_name
	virsh net-autostart $network_name
}


if [ "$#" -eq 0 ];then
	usage
	exit 1
fi

TEMP_OPTIONS=`getopt -o n:m:i:s: --long network-name:,mac-address:,ip-address:,network-mask: --name 'create_network.sh' -- "$@"`

if [ $? -ne 0 ]; then echo "Terminating..." >&2; exit 1; fi

eval set -- "$TEMP_OPTIONS"



while :
do
	case "$1" in
		-n | --network-name)network_name=$2 ; shift 2 ;;
		-m | --mac-address)input_mac_addr=$2 ; shift 2 ;;
		-i | --ip-address)network_ip_addr=$2 ; shift 2 ;;
		-s | --network-mask)net_mask=$2 ; shift 2 ;;
		*)  break ;;
	esac
done

check_input_network_name $network_name
check_if_network_already_exist $network_name
if [ -z "$input_mac_addr" ];then
	input_mac_addr=$random_mac_addr
else
	check_input_mac_address $input_mac_addr
fi
check_if_mac_already_present $input_mac_addr
check_input_ip_addr $network_ip_addr
check_input_network_mask $net_mask
#-----------------------------------------------------------------#
# START DEFINE NETWORK PARAMETERS #
# THIS VARIABLES WILL HELP US WHEN WE WILL CREATE XML FILE TO DEFINE NEW NETWORK #
# ipculc file has function which can calculate network parameters
. ipculc 

#find net_mask in 255.255.0.0 format
netmask $net_mask
found_net_mask=$xml_future_variable


#find broadcast address
broadcast $network_ip_addr $net_mask
found_broadcast_address=$xml_future_variable

#find network address
network $network_ip_addr $net_mask
found_network_address=$xml_future_variable

find_range_start_ip $network_ip_addr
find_range_stop_ip $found_broadcast_address

create_xml_file(){
cat <<EOF > $network_name.xml
<network>
    <name>$network_name</name>
    <forward mode='nat'>
      <nat>
        <port start='1024' end='65535'/>
      </nat>
    </forward>
    <mac address='$input_mac_addr'/>
    <ip address='$gateway_ip' netmask='$found_net_mask'>
      <dhcp>
        <range start='$start_range_ip' end='$range_end_ip' />
      </dhcp>
    </ip>
</network>
EOF
}

check_virbr_interfaces(){
	net_list=( `virsh net-list --all | awk '{print $1}'` )
	#remove 1-st and 2-nd elements because virsh net-list --all | awk '{print $1}' has format
	#net_list=( Name ---------------------------------------------------------- default fedoravms )
	net_list=("${net_list[@]:2}")
	#Next find names of all bridges to avoid assigning already existing virbr interface
	declare -a bridges
	i=0
	while [ $i -lt ${#net_list[@]} ]
	do	
		bridges=( ${bridges[@]} `virsh net-info ${net_list[$i]} | grep Bridge | awk '{print $2}'` ) 
		i=`expr $i + 1`
	done
		
}
#check_virbr_interfaces
create_xml_file
create_define_new_network
