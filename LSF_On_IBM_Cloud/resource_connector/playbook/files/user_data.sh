#!/bin/sh
# -----------------------------------
#  Copyright IBM Corp. 2021. All rights reserved.
#  US Government Users Restricted Rights - Use, duplication or disclosure
#  restricted by GSA ADP Schedule Contract with IBM Corp.
# -----------------------------------

#--This is an example of a basic post provision user script
#  The purpose of this script is to configure the node with
#  needed software and system changes to allow the node to
#  join the lsf cluster.

logfile=/tmp/user_data.log
echo POST PROVISION START `date '+%Y-%m-%d %H:%M:%S'` >> $logfile

%EXPORT_USER_DATA%

LSF_TOP=/opt/ibm/lsf_worker
LSF_CONF_FILE=${LSF_TOP}/conf/lsf.conf
. ${LSF_TOP}/conf/profile.lsf
env >> $logfile

lsf_master_ip=<master_ip>
lsf_master_hname=<master_hostname>
domain_name=<domain_name>
nfs_mnt_dir=<nfs_mnt_dir>

#--create a DNS record for the new instance
################################################################################
DNSSVCS_ENDPOINT="https://api.dns-svcs.cloud.ibm.com"
DNS_INSTANCE_ID=<dns_instance_id>
DNSZONE_ID=<dns_zone_id>

#--NOTE: this relies on the interface being eth0
privateIP=$(ip addr show eth0 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')
hostname=$(hostname)

#--generate an IAM token from the API key
iamtok=$(curl -k -X POST \
  --header "Content-Type: application/x-www-form-urlencoded" \
  --header "Accept: application/json" \
  --data-urlencode "grant_type=urn:ibm:params:oauth:grant-type:apikey" \
  --data-urlencode "apikey=<an IBM Cloud API Key>" \
  "https://iam.cloud.ibm.com/identity/token" | awk -F[,:] '{print $2}' )

#--create the DNS 'A' record json for this machine
gen_postdata()
{
cat <<EOF
{
  "name": "$hostname",
  "type": "A",
  "rdata": {
    "ip": "$privateIP"
  },
  "ttl":900
}
EOF
}

#--create an authorization token json for this node
gen_auth()
{
cat <<EOF
Authorization: ${iamtok//\"/}
EOF
}

#--create a DNS 'PTR' (reverse lookup) record json for this node
gen_ptr()
{
cat <<EOF
{
  "type": "PTR",
  "name": "$privateIP",
  "rdata": {
    "ptrdname": "${hostname}.${domain_name}"
  }
}
EOF
}

################################################################################
#--this function will return the dns record ids of A or PTR records that are 
#  using the same IP as this node. 
getids () {
curl -X GET   $DNSSVCS_ENDPOINT/v1/instances/$DNS_INSTANCE_ID/dnszones/$DNSZONE_ID/resource_records?limit=300 \
  -H 'Content-Type: application/json' \
  -H "$(gen_auth)" | sed 's/,/\n/g' | awk -v tgtip=$privateIP '
BEGIN { FS=":" }
/"name":/ { nm=$2 }

/"id":"A:/ {
        #--next rdata field has IP
        nextrdata=1
        id=sprintf("%s:%s",$2,$3)
}

/"id":"PTR:/ {
        #--previous name field had IP
        gsub(/"/,"",nm)
        if (nm == tgtip) {
                sub(/"/,"",$2)
                sub(/"/,"",$3)
                printf("%s:%s\n",$2,$3)
        }
}

/"rdata":/ {
        gsub(/["}]/,"",$3)
        if (nextrdata && ($3 == tgtip)) {
                gsub(/"/,"",id)
                printf("%s\n",id)
        }
        nextrdata=0
}' | sort -r | uniq
}
#-- end getid() function ########################################################

#--if there are existing DNS records for this IP, they are stale and need to go
#  so that we can create valid ones
recids=$(getids)
numrecs=$(echo $recids | wc -w)
echo There are $numrecs stale DNS records to be deleted >> $logfile
dnserr=true
errcount=0
while $dnserr
do
dnserr=false
if ((numrecs > 0)); then
  for i in $recids
  do
    curl -X DELETE   $DNSSVCS_ENDPOINT/v1/instances/$DNS_INSTANCE_ID/dnszones/$DNSZONE_ID/resource_records/$i \
      -H 'Content-Type: application/json' \
      -H "$(gen_auth)" >> /tmp/DELETElog
  done
fi


#--create a DNS A record for this node
curl -sS -X POST $DNSSVCS_ENDPOINT/v1/instances/$DNS_INSTANCE_ID/dnszones/$DNSZONE_ID/resource_records \
  -H 'Content-Type: application/json' \
  -H "$(gen_auth)" \
  -d "$(gen_postdata)" > /tmp/Areclog

if  grep -iq "error" /tmp/Areclog; then 
	echo "DNS error creating an A record" >> $logfile
	dnserr=true
fi

#--create a PTR (reverse lookup) record for this node
curl -sS -X POST $DNSSVCS_ENDPOINT/v1/instances/$DNS_INSTANCE_ID/dnszones/$DNSZONE_ID/resource_records \
  -H 'Content-Type: application/json' \
  -H "$(gen_auth)" \
  -d "$(gen_ptr)" > /tmp/PTRreclog

if  grep -iq "error" /tmp/PTRreclog; then 
	echo "DNS error creating a PTR record" >> $logfile
	dnserr=true
fi

((errcount+=1))
if ((errcount >= 5))
then
	echo exiting user_data after $errcount attempts to register with DNS >> $logfile
	exit
fi
done

#--add the domain to the search paramater of /etc/resolv.conf and change the
#  config so the setting will persist across reboots and network restarts
echo "PEERDNS=no" >> /etc/sysconfig/network-scripts/ifcfg-eth0
echo "search $domain_name" >> /etc/resolv.conf

#--Join the cluster
################################################################################

sed -i "s/LSF_SERVER_HOSTS=.*$/LSF_SERVER_HOSTS=\"${lsf_master_hname}\"/" $LSF_CONF_FILE

#--fix the resource name on the new host, to match this cluster.  This can be removed if the resource is set to "ibmgen2host" on the master 
sed -i "s/LSF_LOCAL_RESOURCES=\"\[resource ibmgen2host\]\"/LSF_LOCAL_RESOURCES=\"\[resource icgen2host\]\"/" $LSF_CONF_FILE 

# Support rc_account resource to enable RC_ACCOUNT policy
# Add additional local resources if needed
#
if [ -n "${rc_account}" ]; then
sed -i "s/\(LSF_LOCAL_RESOURCES=.*\)\"/\1 [resourcemap ${rc_account}*rc_account]\"/" $LSF_CONF_FILE
echo "update LSF_LOCAL_RESOURCES lsf.conf successfully, add [resourcemap ${rc_account}*rc_account]" >> $logfile
fi

#--set up a unique identifier for this instance
instance_id=$(dmidecode | grep Family | cut -d ' ' -f 2 |head -1)
if [ -n "$instance_id" ]; then
    sed -i "s/\(LSF_LOCAL_RESOURCES=.*\)\"/\1 [resourcemap $instance_id*instanceID]\"/" $LSF_CONF_FILE
    echo "Update LSF_LOCAL_RESOURCES in $LSF_CONF_FILE successfully, add [resourcemap ${instance_id}*instanceID]" >> $LOG_FILE
else
    echo "Can not get instance ID" >> $LOG_FILE
fi


echo LSF_LOG_MASK=LOG_DEBUG3 >> $LSF_CONF_FILE
echo LSF_DEBUG_LIM=LC_TRACE >> $LSF_CONF_FILE
echo LSB_SBD_STARTUP_RETRY_TIMES=3 >> $LSF_CONF_FILE

#--edit /etc/hosts
echo "$lsf_master_ip ${lsf_master_hname}.${domain_name} $lsf_master_hname" >> /etc/hosts
sed -i "/127.0.0.1 ${hostname}/d" /etc/hosts
echo "$privateIP ${hostname}.${domain_name} $hostname" >> /etc/hosts

echo $LSF_CONF_FILE >> $logfile

################################################################################
#--this node is provisioned using an image that contains LSF, so we are mounting
#  nfs to allow access to shared storage.  LSF binaries are from local storage

if yum list installed nfs-utils >/dev/null 2>&1; then
  echo "nfs-utils is already installed" >> $logfile
else
  echo "Installing nfs-utils" >> $logfile
  yum install -y nfs-utils
fi

if [ -d /mnt/nfs ]; then
  echo "/mnt/nfs already exits" >> $logfile
elif yum list installed nfs-utils >/dev/null 2>&1; then
  echo "Creating the nfs mount point" >> $logfile
  mkdir /mnt/nfs
  mount $lsf_master_ip:/mnt/nfs /mnt/nfs
else
  echo "nfs filesystem not mounted" >> $logfile
fi

################################################################################
sleep 5
nohup lsf_daemons start &

echo "Check if the lsf lim daemon is running" >> $logfile
RETRY=0
while ! pgrep -x lim >/dev/null
do
  sleep 5
  (( RETRY++ ))
  if [[ $RETRY > 5 ]]; then
    echo "Give up. The lsf lim daemon cannot be started" >> $logfile
  fi
done

if ! pgrep -x lim >/dev/null; then
  exit 1
else
  echo "The lsf lim daemon is running" >> $logfile
fi

lsf_daemons status >> $logfile
echo END `date '+%Y-%m-%d %H:%M:%S'` >> $logfile

