#!/bin/sh
# -----------------------------------
#  Copyright IBM Corp. 2021. All rights reserved.
#  US Government Users Restricted Rights - Use, duplication or disclosure
#  restricted by GSA ADP Schedule Contract with IBM Corp.
# -----------------------------------

if [ "$#" -ne 1 ]
then
  echo "Usage: $0 vm-name"
  exit 1
fi

# will assume it's only one socket for the VM
socket_per_node=1
# will assume hyper threading is on
smt=2

vm_name=$1
vm_info=$( ibmcloud is ins | grep -w $vm_name | awk '{print $1}' | xargs ibmcloud is in -json )

vpc_id=$( echo $vm_info |
           jq -r '.vpc.id')

image_id=$( echo $vm_info |
           jq -r '.image.id')

subnet_id=$( echo $vm_info |
           jq -r '.primary_network_interface.subnet.id')

sg_id_list=$( echo $vm_info |
	    jq -r '.primary_network_interface.security_groups[] | .id')
zone=$( echo $vm_info |
	jq -r '.zone.name')

region=$( echo $zone | rev | cut -d '-' -f2- | rev )

profile=$( echo $vm_info |
         jq -r '.profile.name')

vcpu=$( echo $vm_info |
	jq -r '.vcpu.count')

vcpu_per_socket=$(( $vcpu/$socket_per_node/$smt ))

#in GB
memory=$( echo $vm_info |
	jq -r '.memory')

memory_mb=$(( $memory*1024 ))

echo "GEN2_Region: $region"
echo "GEN2_Zone: $zone"
echo "GEN2_VPC_ID: $vpc_id"
echo "GEN2_Image_ID: $image_id"
echo "GEN2_SUBNET_ID: $subnet_id"

count=0
sg_count=$( echo -n "$sg_id_list" | grep -c '^' )
sg_str="GEN2_SG_ID: "
for sg in $sg_id_list
do
  sg_str="$sg_str$sg"
  count=$(( $count+1 ))
  if [ $count -lt $sg_count ]; then
    sg_str="$sg_str,"
  fi
    
done
echo $sg_str

echo "GEN2_PROFILE: $profile"
echo "CORES_PER_SOCKET: $vcpu_per_socket"
echo "SOCKET_PER_NODE: $socket_per_node"
echo "MEMORY_PER_NODE: $memory_mb"


