#!/bin/bash
# -----------------------------------
#  Copyright IBM Corp. 2020. All rights reserved.
#  US Government Users Restricted Rights - Use, duplication or disclosure
#  restricted by GSA ADP Schedule Contract with IBM Corp.
# -----------------------------------
#
# This is a script to setup OpenVPN Server/Client VPC between IBM Cloud and onprem site
# The setup is split into setup-client.sh and setup-server.sh
#
# Tasks:
# 1. log into client and create keys for server and client, scripts to setup systemd services, routes, iptables config
# 2. transfer files to the IBM Cloud node dedicated as VPN server, setup systemd, route, iptables
# 3. start server
# 4. start client
#
# Default settings
#-----------------
# Requirements: ssh key setup to access the Cloud node
#
set -e
# script base name
this=`basename "${0}"`
# Mac OS has no readlink -f behavior
if uname -s |grep -q '^Darwin';then
    thisdir="$(cd "`dirname "${0}"`" && pwd -P)"
else
    rl=`readlink -f "${0}"`
    dirname=`dirname "${rl}"`
    thisdir="$(cd "${dirname}" && pwd -P)"
fi
export thisdir=${thisdir}
source "${thisdir}/logging_functions.sh"

##############################################################
# Defaults for running from scratch for the first time
verbose=${verbose:-1} # better be 1
debug=${debug:-2} # better be 1
certs=${certs:-1} # must be 1
setup=${setup:-1} # run actual setup
execute=${execute:-1} # execute the openvpn binary
purge=${purge:-0} # purge installation
yum=${yum:-1}     # must be 1
rpm=${rpm:-1}     # suggested to be 1

# Other required settings are not set but must be provided
floating_ip=${floating_ip:-''} # public IP of the login node / floating IP
onprem_node=${onprem_node:-''}       # use IP if there is no ssh config for this node, root access with keys required
client_nic=${client_nic:-''}   # NIC of this IBM node
vpc_cidr=${vpc_cidr:-""}       # cidr of the subnet in IBM Cloud
vpn_cidr=${vpn_cidr:-""}       # cidr of the VPN
ibm_cidr=${ibm_cidr:-""}       # cidr of the IBM subnet
ssh_config=${ssh_config:-''}   # ssh config file from the terraform generated VPC
lsf_master=${lsf_master:-''}   # IP address of the VPC's master
setup_type=${setup_type:-"master"} # either master or login

# combine all args to pass to all steps at once
opt="--settings --verbose ${verbose} --debug ${debug} --certs ${certs} --purge ${purge} --yum ${yum} --rpm ${rpm} --floating_ip ${floating_ip} --onprem_node ${onprem_node} --client_nic ${client_nic} --vpc_cidr ${vpc_cidr} --vpn_cidr ${vpn_cidr} --ibm_cidr ${ibm_cidr} --ssh_config ${ssh_config} --lsf_master ${lsf_master} --setup_type ${setup_type}"

##############################################################

# Option 1: run OpenVpn server on login node
setup_login_node() {
    # copy files to server
    scp -F ${ssh_config} server.tgz vpn_functions.sh logging_functions.sh setup-server.sh root@${floating_ip}:
    logInfo 1 "${this} RC:$? Copy files to OpenVPN server as ${floating_ip}"
    
    # execute script on server
    ssh -F ${ssh_config} root@${floating_ip} "./setup-server.sh ${opt} --setup 1 --execute 1"
    logInfo 1 "${this} RC:$? Execution of script on ${floating_ip}"
}
# Option 2: run OpenVpn server on LSF master node
setup_master_node() {
    # copy files to master
    scp -F ${ssh_config} server.tgz vpn_functions.sh logging_functions.sh setup-server.sh root@${lsf_master}:
    logInfo 1 "${this} RC:$? Copy files to OpenVPN server as ${lsf_master}"

    # todo:
    # add rules to forward vpn port from login to master
    ssh -F ${ssh_config} root@${floating_ip} "sysctl net.ipv4.ip_forward=1 && iptables -t nat -I PREROUTING -p tcp --dport 1194 -j DNAT --to-destination ${lsf_master}:1194 -m comment --comment \"VPN redirect to master\" && iptables -t nat -I POSTROUTING -j MASQUERADE"
    
    # execute script on lsf master
    ssh -F ${ssh_config} root@${lsf_master} "./setup-server.sh ${opt} --settings --setup 1 --execute 1"
    logInfo 1 "${this} RC:$? Execution of script on ${lsf_master}"
}

#
## main
#

# setup is generated on client onprem
scp vpn_functions.sh logging_functions.sh setup-server.sh setup-client.sh root@${onprem_node}:
logInfo 1 "${this} RC:$? Copy files to OpenVPN client as ${onprem_node}"

# execute script on client
ssh root@${onprem_node} "./setup-client.sh ${opt} --setup 1 --execute 0"
logInfo 1 "${this} RC:$? Execution of script on ${onprem_node}"

# get server tar file from client
scp root@${onprem_node}:server.tgz .
logInfo 1 "${this} RC:$? retrieval of server.tgz from OpenVPN client as ${onprem_node}"

# choice: we use master for simplicity of VPN connection
case ${setup_type} in
    login)
	setup_login_node
	;;
    master)
	setup_master_node
	;;
    *)
	logInfo 1 "${this} ERROR Invalid setup type ${setup_type}"
	exit 1
	;;
esac

# start client
ssh root@${onprem_node} "./setup-client.sh ${opt} --setup 0 --execute 1"
logInfo 1 "${this} RC:$? Starting OpenVPN client on ${onprem_node}"
