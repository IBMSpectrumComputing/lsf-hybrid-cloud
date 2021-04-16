#!/bin/sh
# -----------------------------------
#  Copyright IBM Corp. 2021. All rights reserved.
#  US Government Users Restricted Rights - Use, duplication or disclosure
#  restricted by GSA ADP Schedule Contract with IBM Corp.
# -----------------------------------

if [ "$#" -ne 1 ]
then
  echo "Usage: $0 dns-instance-name"
  exit 1
fi

dns_name=$1
dns_instance_id=$( ibmcloud dns instances | grep -w $dns_name | awk '{print $2}' )

# There may be multiple zones for a given service instance.
# We will assume only one zone exist for this DNS instance.
dns_zone_info=$( ibmcloud dns zones -i $dns_instance_id --output json )

zone_id=$( echo $dns_zone_info |
           jq -r ' .[0] | .id')

domain_name=$( echo $dns_zone_info |
	       jq -r ' .[0] | .name')

echo "GEN2_DNS_Instance_ID: $dns_instance_id"
echo "GEN2_DNS_Zone_ID: $zone_id"
echo "GEN2_DNS_Domain_Name: $domain_name"


