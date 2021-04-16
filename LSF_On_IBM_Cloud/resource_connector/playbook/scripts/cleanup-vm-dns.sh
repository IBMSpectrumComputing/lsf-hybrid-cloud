#!/bin/sh
# -----------------------------------
#  Copyright IBM Corp. 2021. All rights reserved.
#  US Government Users Restricted Rights - Use, duplication or disclosure
#  restricted by GSA ADP Schedule Contract with IBM Corp.
# -----------------------------------

if [ "$#" -ne 2 ]
then
  echo "Usage: $0 vm_prefix dns-instance-name"
  exit 1
fi

vm_prefix=$1
dns_name=$2

#fips=$(ibmcloud is ips | grep ${vm_prefix} | awk '{print $1}')
#for each in $fips
#do
#  echo "CMD: ibmcloud is ipd $each..."
#  echo "y" | ibmcloud is ipd $each
#done


vms=$( ibmcloud is ins | grep ${vm_prefix} | grep running | awk '{print $1}' )
for each in $vms
do
  echo "CMD: ibmcloud is in-stop $each..."
  echo "y" | ibmcloud is in-stop $each

  echo "CMD: ibmcloud is ind $each..."
  echo "y" | ibmcloud is ind $each
done

dns_instance_id=$( ibmcloud dns instances | grep -w $dns_name | awk '{print $2}' )

# There may be multiple zones for a given service instance.
# We will assume only one zone exist for this DNS instance.
dns_zone_info=$( ibmcloud dns zones -i $dns_instance_id --output json )

zone_id=$( echo $dns_zone_info |
           jq -r ' .[0] | .id')

records=$(ibmcloud dns resource-records $zone_id -i $dns_instance_id | grep ${vm_prefix} | awk '{print $1}')
for each in $records
do
  echo "CMD: ibmcloud dns resource-record-delete $zone_id $each -i $dns_instance_id..."
  echo "y" | ibmcloud dns resource-record-delete $zone_id $each -i $dns_instance_id
done
