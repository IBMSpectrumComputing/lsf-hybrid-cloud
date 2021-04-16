#!/bin/sh

#--This is an example of a basic post provision user script
#  The purpose of this script is to configure the node with
#  needed software and system changes to allow the node to
#  join the lsf cluster.

logfile=/tmp/user_data.log
echo POST PROVISION START `date '+%Y-%m-%d %H:%M:%S'` >> $logfile

LSF_TOP=/fake/opt/lsf_worker
LSF_CONF_FILE=${LSF_TOP}/conf/lsf.conf
. ${LSF_TOP}/conf/profile.lsf
env >> $logfile

lsf_master_ip=10.10.10.10
lsf_master_hname=fakehostname.ibm.com
domain_name=fakedomain.ibm.perf
nfs_mnt_dir=/mnt/nfs

#--create a DNS record for the new instance
################################################################################
DNSSVCS_ENDPOINT=https://api.fake-dns-svcs-endpoint.ibm.com
DNS_INSTANCE_ID=fake-dns-instance-id-41ab-b897-475f26ddb64d
DNSZONE_ID=fake-dns-zone-id-4bee-8a0a-38f48ceae3e7

#--NOTE: this relies on the interface being eth0
privateIP=$(ip addr show eth0 | awk '$1 == "inet" {gsub(/\/.*$/, "", $2); print $2}')
hostname=$(hostname)

#--generate an IAM token from the API key
iamtok=$(curl -k -X POST \
  --header "Content-Type: application/x-www-form-urlencoded" \
  --header "Accept: application/json" \
  --data-urlencode "grant_type=urn:ibm:params:oauth:grant-type:apikey" \
  --data-urlencode "apikey=FPLaT_INYIuoRysAQ-xK11kjrlJ6kGQuqZs99hc0UrHI" \
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

#--create a DNS record for this node
curl -sS -X POST $DNSSVCS_ENDPOINT/v1/instances/$DNS_INSTANCE_ID/dnszones/$DNSZONE_ID/resource_records \
  -H 'Content-Type: application/json' \
  -H "$(gen_auth)" \
  -d "$(gen_postdata)" 

#--create a PTR (reverse lookup) record for this node
curl -sS -X POST $DNSSVCS_ENDPOINT/v1/instances/$DNS_INSTANCE_ID/dnszones/$DNSZONE_ID/resource_records \
  -H 'Content-Type: application/json' \
  -H "$(gen_auth)" \
  -d "$(gen_ptr)"

#--Join the cluster
################################################################################
sleep 5

sed -i "s/LSF_SERVER_HOSTS=\"lsfmaster\"/LSF_SERVER_HOSTS=\"${lsf_master_hname}\"/" $LSF_CONF_FILE 

#--fix the resource name on the new host, to match this cluster.  This can be removed if the resource is set to "ibmgen2host" on the master 
sed -i "s/LSF_LOCAL_RESOURCES=\"\[resource ibmgen2host\]\"/LSF_LOCAL_RESOURCES=\"\[resource icgen2host\]\"/" $LSF_CONF_FILE 

# Support rc_account resource to enable RC_ACCOUNT policy
# Add additional local resources if needed
#
if [ -n "${rc_account}" ]; then
sed -i "s/\(LSF_LOCAL_RESOURCES=.*\)\"/\1 [resourcemap ${rc_account}*rc_account]\"/" $LSF_CONF_FILE
echo "update LSF_LOCAL_RESOURCES lsf.conf successfully, add [resourcemap ${rc_account}*rc_account]" >> $logfile
fi

echo LSF_LOG_MASK=LOG_DEBUG3 >> $LSF_CONF_FILE
echo LSF_DEBUG_LIM=LC_TRACE >> $LSF_CONF_FILE

#--edit /etc/hosts
echo "$lsf_master_ip ${lsf_master_hname}.${domain_name} $lsf_master_hname" >> /etc/hosts
sed -i "/127.0.0.1 ${hostname}/d" /etc/hosts
echo "$privateIP ${hostname}.${domain_name} $hostname" >> /etc/hosts

echo $LSF_CONF_FILE >> $logfile

nohup lsf_daemons start &

# prepare the file to register itself to LSF
echo "$privateIP $hostname" > /root/hostregsetup

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
  # now can broadcast the new node
  lsreghost -s /root/hostregsetup
fi

lsf_daemons status >> $logfile
echo END `date '+%Y-%m-%d %H:%M:%S'` >> $logfile
