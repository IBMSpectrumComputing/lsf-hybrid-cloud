#!/bin/bash
# -----------------------------------
#  Copyright IBM Corp. 2020. All rights reserved.
#  US Government Users Restricted Rights - Use, duplication or disclosure
#  restricted by GSA ADP Schedule Contract with IBM Corp.
# -----------------------------------
#
# 2020-07-03 Marc Dombrowa
# Function to create VPN server on IBM Cloud and client on IBM Watson site 
# to allow LSF master to master communication
# Switched to centos, RH, Fedora due to LSF requirement
# Create certificates and keys for server and client on master in IBM Cloud
#
# Requirements:
# - RHEL, Fedora, Centos image (tested on CentOS server , RHEL client)
# - ipcalc from packge: RHEL   : rhel-7-server-rpms
#                       Centos : base
#
# openvpn  : Server & Client 
# easy-rsa : Client https://github.com/OpenVPN/easy-rsa/blob/master/README.quickstart.md
#
# Determine subnet to share, do not collide with subnet of VPC
# Determine NIC on master, client, e.g: eth0, enp1s0f0
# Determine cidr of IBm Cloud's VPC subnet
# Determine Floating IP of server
# Include a rule for incoming tcp/udp traffic on port 1194 in security group of VPC
# 
# Abandoned path from 2020-06-23: patch easyrsa to pass password file into SSL lib
#

VERSION='v1.5 (2020-07-17)'
# vars: also used inside logging_functions.sh
export verbose=${verbose:-1}
export debug=${debug:-0}
export use_color=${use_color:-1}

# because Mac OS is so special in case we want to dry run this script for absolutely no reason
make_temp_dir() {
    local suffix="${1}"

    case `uname -s`
    in "Darwin" )
    	   mktemp -d -t "${suffix}"
	   ;;
       Linux) 
	   mktemp --directory --suffix "${suffix}" --dry-run
	   ;;
    esac
}	
source "${thisdir}/logging_functions.sh" $@

# vars: only used here
print_settings=0
# program defaults
# to clean up installed packages and files
purge=${purge:-0}
# install new packages using yum (for first time setup)
yum=${yum:-1}
# sanity check installed packages via rpm (for paranoia)
rpm=${rpm:-1}
# create the certificates and keys via easyrsa (first timee setup or regen)
certs=${certs:-1}
# setup, install service (install the systemd service to start openvpn server or client)
setup=${setup:-1}
# execute the service (start the service for openvpn server or client)
execute=${execute:-1}

# server settings
SERVER_CONFIG="/etc/openvpn/server.config"
SERVER_SYSTEMD_SERVICE="/etc/systemd/system/openvpn-server.service"
SERVER_IPTABLES_SCRIPT="/root/iptables-server.sh"
SERVER_TARFILE="/root/server.tgz"
SERVER_TEMPDIR="/tmp/server"
SERVER_PKGS="openvpn emacs"
# VPN subnet and mask default
vpn_cidr="" # 10.8.0.0/24" #    TODO
# VPC subnet and mask must be provided
vpc_cidr=""

# provide the floating IP of the node which will serve as VPN server
# must be provided, therefore empty default
floating_ip=""
# nic, using the Alexandria clusters NIC as default must be provided
client_nic=""
# using the IBM Yorktown cidr
ibm_cidr=""

# client settings
CLIENT_CONFIG="/etc/openvpn/client.config"
CLIENT_SYSTEMD_SERVICE="/etc/systemd/system/openvpn-client.service"
CLIENT_IPTABLES_SCRIPT="/root/iptables-client.sh"
CLIENT_TEMPDIR="/tmp/client"
CLIENT_TARFILE="/root/client.tgz"
CLIENT_PKGS="openvpn easy-rsa emacs"

validate_settings() {
    local func="${FUNCNAME[0]}()"
    local variable="${1}"
    local value="${2}"

    if [ "${value}" = "" ]; then
	logError "${func} Empty value for ${variable}, exiting ${this} with rc=1"
	exit 1
    fi     
}
validate_all_settings() {
    validate_settings verbose ${verbose}
    validate_settings debug ${debug}
    validate_settings certs ${certs}
    validate_settings purge ${purge}
    validate_settings setup ${setup}
    validate_settings execute ${execute}
    validate_settings yum ${yum}
    validate_settings rpm ${rpm}
    validate_settings floating_ip ${floating_ip}
    validate_settings onprem_node ${onprem_node}
    validate_settings client_nic ${client_nic}
    validate_settings vpc_cidr ${vpc_cidr}
    validate_settings vpn_cidr ${vpn_cidr}
    validate_settings ibm_cidr ${ibm_cidr}
    validate_settings ssh_config ${ssh_config}
    validate_settings lsf_master ${lsf_master}
    validate_settings setup_type ${setup_type}
}
validate_ipcalc() {
    if ipcalc 1>/dev/null 2>&1; then
	logError "${this} No ipcalc available, exiting with rc=1"
	exit 1
    fi
}
# calculate the network address from a cidr
network_from_cidr() {
    local func="${FUNCNAME[0]}()"
    local cidr="${1}"

    validate_settings cidr "${cidr}"
    ipcalc --network "${cidr}"|sed 's/^NETWORK=//'
}
# calculate the network mask from a cidr
netmask_from_cidr() {
    local func="${FUNCNAME[0]}()"
    local cidr="${1}"

    validate_settings cidr "${cidr}"
    ipcalc --netmask "${cidr}"|sed 's/^NETMASK=//'
}
    
IPprefix_by_netmask() {
    local mask=${1}

    validate_settings mask ${mask}
    # function returns prefix for given netmask in arg1
    ipcalc --prefix 1.1.1.1 "${mask}" | sed -n 's/^PREFIX=\(.*\)/\/\1/p'
}

show_settings() {
    logInfo 1 "${this} verbose     = ${verbose}"
    logInfo 1 "${this} debug       = ${debug}"
    logInfo 1 "${this} certs       = ${certs}"
    logInfo 1 "${this} yum         = ${yum}"
    logInfo 1 "${this} rpm         = ${rpm}"
    logInfo 1 "${this} floating_ip = ${floating_ip}"
    logInfo 1 "${this} onprem_node    = ${onprem_node}"
    logInfo 1 "${this} client_nic  = ${client_nic}"
    logInfo 1 "${this} vpc_cidr    = ${vpc_cidr}"
    logInfo 1 "${this} vpn_cidr    = ${vpn_cidr}"
    logInfo 1 "${this} ibm_cidr    = ${ibm_cidr}"
    logInfo 1 "${this} ssh_config  = ${ssh_config}"
    logInfo 1 "${this} lsf_master  = ${lsf_master}"
    logInfo 1 "${this} setup_type  = ${setup_type}"
    logInfo 1 "${this} opt         = ${opt}"
    logInfo 1 "${this} PS4         = ${PS4}"
}

print_help() {
    echo "
Usage: ${this} [OPTION...] 
Setup OpenVPN server inside a Centos, RedHat, Fedora IBM Cloud instance

  -h,--help                display this help and exit
  -V,--version             output version information and exit
  -p,--purge [0|1]         purge installation (default: 0)
  -y,--yum [0|1]     	   install packages via yum (default: 1)
  -r,--rpm [0|1]     	   check packages via rpm (default: 1)
  -c,--certs [0|1]   	   create certificates using easy-rsa (default: 1)
  -s,--setup [0|1]   	   setup the services (default: 1)
  -e,--execute    	   execute the service (default: 1)
     --start [0|1]
     --settings 	   print settings (default: no)
  -f,--floating_ip         floating ip of VPC (default: none)
     --onprem_node            IP of the IBM node onprem (default: none)
     --client_nic          NIC in vpn client  (default: enp1s0f0)
     --vpn_cidr            cidr of the OpenVPN server tunnel subnet (default: none)
     --vpc_cidr            cidr of the IBM Cloud VPC (default: none)
     --ibm_cidr            cidr of the IBM route (default none)
     --ssh_config          path for ssh config (default: none)
     --lsf_master          IP of the LSF master node (default: none)
     --setup_type          mode of installation, VPN server on login or master node (default: none)
  -v,--verbose [0..n]      set verbosity level (default: 1)
  -d,--debug [0..n]        set debug level (default: 0)

Examples:
  ${this} --purge --settings --verbose 1 --debug 1 --certs 1 --yum 1 --rpm 1 --floating_ip 1.2.3.4 --onprem_node netsres12 --client_nic enp1s0f0 --vpc_cidr 10.243.0.0/24 --vpn_cidr 10.8.0.0/24 --ibm_cidr 4.3.0.0/16 --ssh_config ${GEN_FILES_DIR}/ssh_config --lsf_master 10.243.0.4 --setup_type login
"
}

# command line parsing
logDebug 1 "${this} CMDLINE= ${0} $@"
while true; do
    case "${1}" in
      -p|--purge) if [ "${1}"  != "" ]; then shift;  purge=${1}; fi; shift;;
      -y|--yum ) if [ "${1}"  != "" ]; then shift;  yum=${1}; fi; shift;;
      -r|--rpm ) if [ "${1}"  != "" ]; then shift;  rpm=${1}; fi; shift;;
      -c|--certs) if [ "${1}"  != "" ]; then shift;  certs=${1}; fi; shift;;
      -s|--setup) if [ "${1}"  != "" ]; then shift;  setup=${1}; fi; shift;;
      --settings) print_settings=1; shift;;
      -v|--verbose) if [ "${1}"  != "" ]; then shift;  verbose=${1}; fi; shift;;
      -d|--debug) if [ "${1}"  != "" ]; then shift;  debug=${1}; fi;
		  # extreme debug
		  if [[ ${debug} -gt 1 ]];then
		      export PS4='+(`basename ${BASH_SOURCE}`:${LINENO}):'
		      set -xe
		  fi		  
		  shift;;
      -e|--execute) if [ "${1}"  != "" ]; then shift; execute=${1}; fi; shift;;
      -f|--floating_ip) if [ "${1}"  != "" ]; then shift; floating_ip=${1}; fi; shift;;
            --onprem_node) if [ "${1}"  != "" ]; then shift; onprem_node=${1}; fi; shift;;
         --client_nic) if [ "${1}"  != "" ]; then shift; client_nic=${1}; fi; shift;;
         --vpn_cidr) if [ "${1}"  != "" ]; then shift; vpn_cidr=${1}; fi; shift;;
         --vpc_cidr) if [ "${1}"  != "" ]; then shift; vpc_cidr=${1}; fi; shift;;
         --ibm_cidr) if [ "${1}"  != "" ]; then shift; ibm_cidr=${1}; fi; shift;;
         --ssh_config) if [ "${1}"  != "" ]; then shift; ssh_config=${1}; fi; shift;;
         --lsf_master) if [ "${1}"  != "" ]; then shift; lsf_master=${1}; fi; shift;;
         --setup_type) if [ "${1}"  != "" ]; then shift; setup_type=${1}; fi; shift;;
      -h|--help) print_help; exit 0;;
      -V|--version) echo ${this} ${VERSION}; exit 0;;
      -- ) shift; break ;;
    * ) break ;;
  esac
done

server_purge() {
    local func="${FUNCNAME[0]}()"

    test -r ${SERVER_SYSTEMD_SERVICE} && systemctl stop openvpn-server && \
	systemctl disable openvpn-server && \
	rm -f ${SERVER_SYSTEMD_SERVICE} && \
	systemctl daemon-reload
    logInfo 1 "${func} Purging ${SERVER_PKGS}"
    yum remove -y ${SERVER_PKGS}
    test -x ${SERVER_IPTABLES_SCRIPT} && ${SERVER_IPTABLES_SCRIPT} stop
    rm -fr /etc/openvpn ${SERVER_IPTABLES_SCRIPT} ${SERVER_TARFILE}
}

server_yum() {
    local func="${FUNCNAME[0]}()"
    # disable set -xe during yum
    set +xe
    yum -y install epel-release
    yum -y update
    yum -y install ${SERVER_PKGS}
    if [[ ${debug} -gt 1 ]];then
	set -xe
    fi
}

server_create_tarfile() {
    local func="${FUNCNAME[0]}()"
    
    mkdir -p ${SERVER_TEMPDIR}/etc/openvpn ${SERVER_TEMPDIR}/var/log/openvpn
    local file target
    for file in \
	/usr/share/easy-rsa/3/pki/ca.crt \
	    /usr/share/easy-rsa/3/pki/issued/server.crt \
	    /usr/share/easy-rsa/3/pki/private/server.key \
	    /usr/share/easy-rsa/3/pki/dh.pem \
	    /usr/share/easy-rsa/3/ta.key ;do
	target="${SERVER_TEMPDIR}/etc/openvpn/`basename "${file}"`"
	cp -pf "${file}" "${target}" && chmod 400 "${target}"
	logInfo 1 "${func} Copied ${file} to ${target}"
    done

    cd ${SERVER_TEMPDIR}
    tar -zcf ${SERVER_TARFILE} etc var root
    logInfo 1 "${func} Server tar file saved as ${SERVER_TARFILE}"
}    

server_create_certificates() {
    local func="${FUNCNAME[0]}()"

    logInfo 1 "${func} Logging to dir ${logdir}"
    # initialize
    cd /usr/share/easy-rsa/3

    local log=${logdir}/init-pki.log
    echo yes | ./easyrsa init-pki 1>${log} 2>&1
    logInfo 1 "${func} ./easyrsa init-pki"; ((step=step+1))
    logDebug 2 "${func} ${log}: `cat ${log}`"

    # build certificate with no passphrase
    log=${logdir}/build-ca.log
    echo server | ./easyrsa build-ca nopass 1>${log} 2>&1
    logInfo 1 "${func} ./easyrsa build-ca"; ((step=step+1))
    logDebug 2 "${func} ${log}: `cat ${log}`"
    
    # build server keypair, generate request for server
    log=${logdir}/gen-req.server.log
    echo | ./easyrsa gen-req server nopass 1>${log} 2>&1
    logInfo 1 "${func} ./easyrsa gen-req server nopass"; ((step=step+1))
    logDebug 2 "${func} ${log}: `cat ${log}`"
    
    # client keypair    
    log=${logdir}/gen-req.client.log
    echo | ./easyrsa gen-req client nopass 1>${log} 2>&1
    logInfo 1 "${func} ./easyrsa gen-req client nopass"; ((step=step+1))
    logDebug 2 "${func} ${log}: `cat ${log}`"
    
    log=${logdir}/sign-req.server.log
    echo yes | ./easyrsa sign-req server server 1>${log} 2>&1
    logInfo 1 "${func} ./easyrsa sign-req server server"; ((step=step+1))
    logDebug 2 "${func} ${log}: `cat ${log}`"
    
    log=${logdir}/sign-req.client.log
    echo yes | ./easyrsa sign-req client client 1>${log} 2>&1
    logInfo 1 "${func} ./easyrsa sign-req client client"; ((step=step+1))
    logDebug 2 "${func} ${log}: `cat ${log}`"

    log=${logdir}/gen-dh.log
    logDebug 1 "${func} ${log}: Generating dh key.."
    ./easyrsa gen-dh 1>${log} 2>&1
    logInfo 1 "${func} ./easyrsa gen-dh"; ((step=step+1))
    logDebug 2 "${func} ${log}: `cat ${log}`"
    
    # create a static key
    log=${logdir}/genkey.ta.log
    openvpn --genkey --secret ta.key 1>${log} 2>&1
    logInfo 1 "${func} openvpn --genkey --secret ta.key"; ((step=step+1));
    logDebug 2 "${func} ${log}: `cat ${log}`"
}

install_tar_file() {
    local func="${FUNCNAME[0]}()"
    local tarfile=${1:-/dev/null}
    
    if [ ! -r ${tarfile} ]; then
	logError "${func} Missing tarfile ${tarfile}"
	exit 1
    fi
    tar -C / -zxf ${tarfile}
}
server_create_config() {
    local func="${FUNCNAME[0]}()"
    local config=${1:-"${SERVER_TEMPDIR}${SERVER_CONFIG}"}
    local vpn_cidr="${2}"
    local vpc_cidr="${3}"

    logDebug 1 "${func} config=${config} | vpn_cidr=${vpn_cidr} | vpc_cidr=${vpc_cidr}"

    mkdir -p "`dirname "${config}"`"
    local vpn_network=`network_from_cidr "${vpn_cidr}"`
    local vpn_mask=`netmask_from_cidr "${vpn_cidr}"`
    local vpc_network=`network_from_cidr "${vpc_cidr}"`
    local vpc_mask=`netmask_from_cidr "${vpc_cidr}"`

    logInfo 1 "${func} vpn_network = ${vpn_network}" 
    logInfo 1 "${func} vpn_mask    = ${vpn_mask}" 
    logInfo 1 "${func} vpc_network = ${vpc_network}" 
    logInfo 1 "${func} vpc_mask    = ${vpc_mask}" 

    if [ "${vpn_network}" = "" ]; then
	logError "${func} Invalid vpn_network from ${vpn_cidr}"
	exit 1
    fi
    if [ "${vpn_mask}" = "" ]; then
	logError "${func} Invalid vpn_mask from ${vpn_cidr}"
	exit 1
    fi
    if [ "${vpc_network}" = "" ]; then
	logError "${func} Invalid vpc_network from ${vpc_cidr}"
	exit 1
    fi
    if [ "${vpc_mask}" = "" ]; then
	logError "${func} Invalid vpc_mask from ${vpn_cidr}"
	exit 1
    fi
    local ibm_route="`network_from_cidr "${ibm_cidr}"` `netmask_from_cidr "${ibm_cidr}"`"
    
    # create server config
    cat > ${config} <<EOF
local 0.0.0.0
port 1194
proto tcp4-server
dev tun
ca /etc/openvpn/ca.crt
cert /etc/openvpn/server.crt
key /etc/openvpn/server.key  # This file should be kept secret
dh /etc/openvpn/dh.pem
;topology subnet
server ${vpn_network} ${vpn_mask} 
ifconfig-pool-persist /var/log/openvpn/ipp.txt
;server-bridge 10.8.0.4 255.255.255.0 10.8.0.50 10.8.0.100
;server-bridge
;push "dhcp-option DNS 8.8.8.8"
# push the servers subnet to client
push "route ${vpc_network} ${vpc_mask}"
client-config-dir /etc/openvpn/ccd
# Yorktown all
route ${ibm_route}
;learn-address ./script
;push "redirect-gateway def1 bypass-dhcp"
;push "dhcp-option DNS 208.67.222.222"
;push "dhcp-option DNS 208.67.220.220"
client-to-client
;duplicate-cn
keepalive 10 120
tls-auth /etc/openvpn/ta.key 0 # This file is secret
cipher AES-256-CBC
;compress lz4-v2
;push "compress lz4-v2"
;comp-lzo
;max-clients 100
user nobody
group nobody # nogroup in ubuntu
persist-key
persist-tun
status /var/log/openvpn/openvpn-status.log
;log         /var/log/openvpn/openvpn.log
;log-append  /var/log/openvpn/openvpn.log
verb 3
;mute 20
;explicit-exit-notify 1
EOF
    logInfo 1 "${func} Created ${config}"
}
server_create_systemd_service() {
    local func="${FUNCNAME[0]}()"
    local config=${1:-"${SERVER_TEMPDIR}${SERVER_SYSTEMD_SERVICE}"}

    mkdir -p "`dirname "${config}"`"
    # create openvpn-server service file
    cat > ${config} <<EOF
[Unit]
Description=OpenVPN server
After=network.target

[Service]
#Type=notify
#NotifyAccess=all
Type=simple
ExecStart=/usr/sbin/openvpn --config ${SERVER_CONFIG}
#Restart=on-failure
Restart=always
RestartSec=90
StartLimitBurst=3
StartLimitInterval=10

ExecStopPost=/bin/systemctl restart systemd-resolved.service

[Install]
WantedBy=multi-user.target
EOF
    logInfo 1 "${func} Created ${config}"

}
activate_forwarding() {
    local func="${FUNCNAME[0]}()"
    
    # activate ipv4 fw
    if ! sysctl net.ipv4.ip_forward | grep -q '=.*1$'; then
	logInfo 1 "${func} Change ip v4 forwarding to 1"
	sysctl net.ipv4.ip_forward=1
	# permanent
	local file=/etc/sysctl.d/ipfw
	echo "sysctl net.ipv4.ip_forward=1" > ${file}
	logInfo 1 "${func} Created ${file}"
    fi
}
server_setup_iptables() {
    local func="${FUNCNAME[0]}()"
    local config=${1:-"${SERVER_IPTABLES_SCRIPT}"}
    local nic=${2:-"eth0"}
    mkdir -p "`dirname "${config}"`"

    # create config
    cat > ${config} <<EOF
#!/bin/bash
#
# allow VPN traffic to access the subnet
#default via 10.240.128.1 dev ${nic} 

fake=\${fake:-1}
action=\${1:-start}
start=0
case \${action} in 
    start)
	start=1
	;;
    stop)
	;;
    *)
	echo "Invalid action \${action}"
	exit 1
	;;
esac

# security
while iptables -D INPUT -j DROP 1>/dev/null 2>&1; do printf '' ; done
while iptables -D INPUT -p tcp -m tcp --dport 113 -m comment --comment 'PING' -j REJECT --reject-with icmp-port-unreachable 1>/dev/null 2>&1; do printf '' ; done
while iptables -D INPUT -p tcp -m tcp --dport 22 -s 129.34.0.0/16 -m comment --comment 'SSH server' -j ACCEPT 1>/dev/null 2>&1; do printf '' ; done
while iptables -D INPUT -p icmp -m icmp --icmp-type 0 -m comment --comment PING -j ACCEPT 1>/dev/null 2>&1; do printf '' ; done
while iptables -D INPUT -p icmp -m icmp --icmp-type 3 -m comment --comment PING -j ACCEPT 1>/dev/null 2>&1; do printf '' ; done
while iptables -D INPUT -p icmp -m icmp --icmp-type 4 -m comment --comment PING -j ACCEPT 1>/dev/null 2>&1; do printf '' ; done
while iptables -D INPUT -p icmp -m icmp --icmp-type 8 -m comment --comment PING -j ACCEPT 1>/dev/null 2>&1; do printf '' ; done
while iptables -D INPUT -p icmp -m icmp --icmp-type 9 -m comment --comment PING -j ACCEPT 1>/dev/null 2>&1; do printf '' ; done
while iptables -D INPUT -p icmp -m icmp --icmp-type 11 -m comment --comment PING -j ACCEPT 1>/dev/null 2>&1; do printf '' ; done
while iptables -D INPUT -p icmp -m icmp --icmp-type 12 -m comment --comment PING -j ACCEPT 1>/dev/null 2>&1; do printf '' ; done
# VPN
while iptables -D INPUT -p tcp -m tcp --dport 1194 -s 129.34.0.0/16 -m comment --comment 'VPN server' -j ACCEPT 1>/dev/null 2>&1; do printf '' ; done
while iptables -D INPUT -i tun0 -m comment --comment 'VPN allow tun0' -j ACCEPT 1>/dev/null 2>&1; do printf '' ; done
while iptables -D FORWARD -i tun0 -o ${nic}  -m comment --comment 'VPN forward' -j ACCEPT 1>/dev/null 2>&1; do printf '' ; done
while iptables -D FORWARD -i ${nic} -o tun0 -m state --state RELATED,ESTABLISHED -m comment --comment 'VPN reverse' -j ACCEPT 1>/dev/null 2>&1; do printf '' ; done
while iptables -D POSTROUTING -t nat -s ${vpn_cidr} ! -d ${vpn_cidr} -o ${nic} -m comment --comment 'VPN route' -j MASQUERADE 1>/dev/null 2>&1; do printf '' ; done

if((start==0)); then exit ;fi

if((start)); then
    iptables -I INPUT -p tcp -m tcp --dport 113 -m comment --comment 'PING' -j REJECT --reject-with icmp-port-unreachable
    iptables -I INPUT -p tcp -m tcp --dport 22 -s 129.34.0.0/16 -m comment --comment 'SSH server' -j ACCEPT
    iptables -I INPUT -p icmp -m icmp --icmp-type 0 -m comment --comment PING -j ACCEPT
    iptables -I INPUT -p icmp -m icmp --icmp-type 3 -m comment --comment PING -j ACCEPT
    iptables -I INPUT -p icmp -m icmp --icmp-type 4 -m comment --comment PING -j ACCEPT
    iptables -I INPUT -p icmp -m icmp --icmp-type 8 -m comment --comment PING -j ACCEPT
    iptables -I INPUT -p icmp -m icmp --icmp-type 9 -m comment --comment PING -j ACCEPT
    iptables -I INPUT -p icmp -m icmp --icmp-type 11 -m comment --comment PING -j ACCEPT
    iptables -I INPUT -p icmp -m icmp --icmp-type 12 -m comment --comment PING -j ACCEPT
    # VPN
    iptables -I INPUT -p tcp -m tcp --dport 1194 -s 129.34.0.0/16 -m comment --comment 'VPN server' -j ACCEPT
    iptables -I INPUT -i tun0 -m comment --comment 'VPN allow tun0' -j ACCEPT
    iptables -I FORWARD -i tun0 -o ${nic}  -m comment --comment 'VPN forward' -j ACCEPT
    iptables -I FORWARD -i ${nic} -o tun0 -m state --state RELATED,ESTABLISHED -m comment --comment 'VPN reverse' -j ACCEPT
    iptables -I POSTROUTING -t nat -s ${vpn_cidr} ! -d ${vpn_cidr} -o ${nic} -m comment --comment 'VPN route' -j MASQUERADE
    # drop all other input
    #iptables -A INPUT -j DROP
fi
EOF
    chmod 750 ${config}
    logInfo 1 "${func} Created ${config}"
}

client_create_tarfile() {
    local func="${FUNCNAME[0]}()"
    
    mkdir -p ${CLIENT_TEMPDIR}/etc/openvpn ${CLIENT_TEMPDIR}/var/log/openvpn
    local file target
    for file in \
	/usr/share/easy-rsa/3/pki/ca.crt \
	    /usr/share/easy-rsa/3/pki/issued/client.crt \
	    /usr/share/easy-rsa/3/pki/private/client.key \
	    /usr/share/easy-rsa/3/pki/dh.pem \
	    /usr/share/easy-rsa/3/ta.key	;do
	target="${CLIENT_TEMPDIR}/etc/openvpn/`basename "${file}"`"
	cp -pf "${file}" "${target}" && chmod 400 "${target}"
	logInfo 1 "${func} Copied ${file} to ${target}"
    done

    tar -C ${CLIENT_TEMPDIR} -zcf ${CLIENT_TARFILE} etc root
    logInfo 1 "${func} Client tar file saved as ${CLIENT_TARFILE}"
}    

server_create_client_route() {
    local func="${FUNCNAME[0]}()"
    local client=${1:-"${CLIENT_TEMPDIR}/etc/openvpn/client"}

    mkdir -p "`dirname "${client}"`"
    # to allow server access IBM client network
    local ibm_route="`network_from_cidr "${ibm_cidr}"` `netmask_from_cidr "${ibm_cidr}"`"
    echo "iroute ${ibm_route}" > ${client}
    chmod 644 "${client}"
    logInfo 1 "${func} Created ${client}"
}

server_setup() {
    local func="${FUNCNAME[0]}()"

    validate_all_settings
    validate_ipcalc
    if [[ ${print_settings} -ne 0 ]]; then
	show_settings
    fi
    if [[ ${purge} -ne 0 ]] ; then
	server_purge
	return
    fi
    if [[ ${yum} -ne 0 ]] ; then
	server_yum
    fi
    if [[ ${rpm} -ne 0 ]] ; then
	for pkg in ${SERVER_PKGS} ;do
	    if ! rpm -qa | grep ${pkg}; then
		logError "${func} Missing package ${pkg}"
		return 1    	     
	    fi
	done
    fi
    # also start
    if [[ ${setup} -ne 0 ]] ; then
	install_tar_file ${SERVER_TARFILE}
	activate_forwarding
	${SERVER_IPTABLES_SCRIPT} start
	iptables-save  > /etc/sysconfig/iptables.v4
	# reload, enable
    fi
    if [[ ${execute} -ne 0 ]] ; then
	systemctl daemon-reload
	systemctl enable openvpn-server
    	systemctl status openvpn-server 1>/dev/null 2>&1 && systemctl stop openvpn-server && logInfo 1 "${func} Stopped openvpn-server"
    	systemctl start openvpn-server && logInfo 1 "${func} Started openvpn-server"
	systemctl status openvpn-server
    fi
    logInfo 1 "${func} completed successfully"
}
##########################################################################
# client functions

# provide vars to the sourced script below
#export verbose=${verbose}
#export debug=${debug}
source "${thisdir}/logging_functions.sh" $@

client_purge() {
    local func="${FUNCNAME[0]}()"

    test -r ${CLIENT_SYSTEMD_SERVICE} && systemctl stop openvpn-client && \
	systemctl disable openvpn-client && \
	rm -f ${CLIENT_SYSTEMD_SERVICE} && \
	systemctl daemon-reload
    logInfo 1 "${func} Purging ${CLIENT_PKGS}"
    yum remove -y ${CLIENT_PKGS}
    test -x ${CLIENT_IPTABLES_SCRIPT} && ${CLIENT_IPTABLES_SCRIPT} stop
    rm -fr /etc/openvpn /usr/share/easy-rsa /tmp/{client,server} /root/{client,server}.tgz ${CLIENT_IPTABLES_SCRIPT} ${CLIENT_TARFILE}
}

client_yum() {
    local func="${FUNCNAME[0]}()"
    # disable set -xe during yum
    set +xe
    yum -y install epel-release
    yum -y update
    yum -y install ${CLIENT_PKGS}
    if [[ ${debug} -gt 1 ]];then
	set -xe
    fi
}

client_create_config() {
    local func="${FUNCNAME[0]}()"
    local config=${1:-"${CLIENT_TEMPDIR}${CLIENT_CONFIG}"}

    if [ "${floating_ip}" = "" ]; then
	logError "${func} Missing floating_ip"
	print_help
	exit 1
    fi
    mkdir -p "`dirname "${config}"`"
    # create config
    cat > ${config} <<EOF
client
dev tun
proto tcp
remote ${floating_ip} 1194
float
user nobody
persist-tun
persist-key
keepalive 15 60
key-direction 1
tls-client
remote-cert-tls server
resolv-retry infinite
nobind
auth-nocache
# WARNINGS
#comp-lzo adaptive
#link-mtu 1543
cipher AES-256-CBC
# client side
ca /etc/openvpn/ca.crt 
key /etc/openvpn/client.key
cert /etc/openvpn/client.crt
tls-auth /etc/openvpn/ta.key 1
group nobody
EOF
    logInfo 1 "${func} Created ${config}"
}

client_setup_iptables() {
    local func="${FUNCNAME[0]}()"
    local config=${1}
    mkdir -p "`dirname "${config}"`"
    # create client config
    cat > ${config} <<EOF
#!/bin/bash
#
# allow VPN traffic to access the subnet

action=\${1:-start}
start=0
case \${action} in 
    start)
	start=1
	;;
    stop)
	;;
    *)
	echo "Invalid action \${action}"
	exit 1
	;;
esac

# default security
while iptables -D INPUT -j DROP 1>/dev/null 2>&1; do printf '' ; done
while iptables -D INPUT -p tcp -m tcp --dport 113 -m comment --comment 'PING' -j REJECT --reject-with icmp-port-unreachable 1>/dev/null 2>&1; do printf '' ; done
#while iptables -D INPUT -p icmp -m icmp --icmp-type 0 -m comment --comment PING -j ACCEPT 1>/dev/null 2>&1; do printf '' ; done
#while iptables -D INPUT -p icmp -m icmp --icmp-type 3 -m comment --comment PING -j ACCEPT 1>/dev/null 2>&1; do printf '' ; done
#while iptables -D INPUT -p icmp -m icmp --icmp-type 4 -m comment --comment PING -j ACCEPT 1>/dev/null 2>&1; do printf '' ; done
#while iptables -D INPUT -p icmp -m icmp --icmp-type 8 -m comment --comment PING -j ACCEPT 1>/dev/null 2>&1; do printf '' ; done
#while iptables -D INPUT -p icmp -m icmp --icmp-type 9 -m comment --comment PING -j ACCEPT 1>/dev/null 2>&1; do printf '' ; done
#while iptables -D INPUT -p icmp -m icmp --icmp-type 11 -m comment --comment PING -j ACCEPT 1>/dev/null 2>&1; do printf '' ; done
#while iptables -D INPUT -p icmp -m icmp --icmp-type 12 -m comment --comment PING -j ACCEPT 1>/dev/null 2>&1; do printf '' ; done
# VPN 
while iptables -D INPUT -i tun0 -m comment --comment "VPN input allow" -j ACCEPT 1>/dev/null 2>&1; do printf '' ; done
while iptables -D FORWARD -i tun0 -o ${client_nic}  -m comment --comment "VPN forward" -j ACCEPT 1>/dev/null 2>&1; do printf '' ; done
while iptables -D FORWARD -i ${client_nic} -o tun0 -m state --state RELATED,ESTABLISHED -m comment --comment "VPN reverse" -j ACCEPT 1>/dev/null 2>&1; do printf '' ; done
while iptables -t nat -D POSTROUTING -s ${vpn_cidr} -d ${ibm_cidr} -o ${client_nic} -m comment --comment "VPN to IBM" -j MASQUERADE 1>/dev/null 2>&1; do printf '' ; done
while iptables -t nat -D POSTROUTING -d ${vpn_cidr} -s ${ibm_cidr} -o tun0 -m comment --comment "IBM to VPN" -j MASQUERADE 1>/dev/null 2>&1; do printf '' ; done

if((start==0)); then exit ;fi

if((start)); then
    # security
    #iptables -I INPUT -p icmp -m icmp --icmp-type 0 -m comment --comment PING -j ACCEPT
    #iptables -I INPUT -p icmp -m icmp --icmp-type 3 -m comment --comment PING -j ACCEPT
    #iptables -I INPUT -p icmp -m icmp --icmp-type 4 -m comment --comment PING -j ACCEPT
    #iptables -I INPUT -p icmp -m icmp --icmp-type 8 -m comment --comment PING -j ACCEPT
    #iptables -I INPUT -p icmp -m icmp --icmp-type 9 -m comment --comment PING -j ACCEPT
    #iptables -I INPUT -p icmp -m icmp --icmp-type 11 -m comment --comment PING -j ACCEPT
    #iptables -I INPUT -p icmp -m icmp --icmp-type 12 -m comment --comment PING -j ACCEPT
    # VPN
    iptables -I INPUT -i tun0 -m comment --comment "VPN input allow" -j ACCEPT
    iptables -I FORWARD -i tun0 -o ${client_nic}  -m comment --comment "VPN forward" -j ACCEPT
    iptables -I FORWARD -i ${client_nic} -o tun0 -m state --state RELATED,ESTABLISHED -m comment --comment "VPN reverse" -j ACCEPT
    iptables -t nat -I POSTROUTING -s ${vpn_cidr} -d ${ibm_cidr} -o ${client_nic} -m comment --comment "VPN to IBM" -j MASQUERADE
    iptables -t nat -I POSTROUTING -d ${vpn_cidr} -s ${ibm_cidr} -o tun0 -m comment --comment "IBM to VPN" -j MASQUERADE
fi
EOF
    chmod 750 ${config}
    logInfo 1 "${func} Created ${config}"
}

client_create_systemd_service() {
    local func="${FUNCNAME[0]}()"
    local config=${1:-"${CLIENT_TEMPDIR}${CLIENT_SYSTEMD_SERVICE}"}

    mkdir -p "`dirname "${config}"`"
    # create openvpn-client service file
    cat > "${config}" <<EOF
[Unit]
Description=OpenVPN client
After=network.target

[Service]
#Type=notify
#NotifyAccess=all
Type=simple
ExecStart=/usr/sbin/openvpn --config ${CLIENT_CONFIG}
#Restart=on-failure
Restart=always
RestartSec=90
StartLimitBurst=3
StartLimitInterval=10

ExecStopPost=/bin/systemctl restart systemd-resolved.service

[Install]
WantedBy=multi-user.target
EOF
    logInfo 1 "${func} Created ${config}"
}

setup_client() {
    local func="${FUNCNAME[0]}()"

    validate_all_settings
    validate_ipcalc
    if [[ ${print_settings} -ne 0 ]]; then
	show_settings
    fi
    if [[ ${purge} -ne 0 ]] ; then
	client_purge
	return
    fi
    if [[ ${yum} -ne 0 ]] ; then
	client_yum
    fi
    if [[ ${rpm} -ne 0 ]] ; then
	local pkg=''
	for pkg in ${CLIENT_PKGS}; do
	    if ! rpm -qa | grep ${pkg}; then
		logError "${func} Missing package ${pkg}"
		exit 3    	     
	    fi
	done
    fi
    if [[ ${setup} -ne 0 ]] ; then
	# create in temp dir
	logDebug 1 "${func} server_create_config config=${SERVER_TEMPDIR}${SERVER_CONFIG} | vpn_cidr=${vpn_cidr} | vpc_cidr=${vpc_cidr}"
	server_create_config "${SERVER_TEMPDIR}${SERVER_CONFIG}" "${vpn_cidr}" "${vpc_cidr}"
	server_create_client_route "${SERVER_TEMPDIR}/etc/openvpn/ccd/client"
	
	# make this a template with args
	server_setup_iptables ${SERVER_TEMPDIR}${SERVER_IPTABLES_SCRIPT} "eth0"
	server_create_systemd_service ${SERVER_TEMPDIR}${SERVER_SYSTEMD_SERVICE}
    fi
    if [[ ${certs} -ne 0 ]] ; then
	server_create_certificates
    fi

    if [[ ${setup} -ne 0 ]] ; then
	# collect certs, config, firewall script
	server_create_tarfile	
	client_create_config ${CLIENT_TEMPDIR}${CLIENT_CONFIG}
	client_setup_iptables ${CLIENT_TEMPDIR}${CLIENT_IPTABLES_SCRIPT}
	client_create_systemd_service ${CLIENT_TEMPDIR}${CLIENT_SYSTEMD_SERVICE}
	client_create_tarfile
    	activate_forwarding
    	install_tar_file "${CLIENT_TARFILE}"
    	${CLIENT_IPTABLES_SCRIPT} start
    	# reload, enable
    	systemctl daemon-reload
    	systemctl enable openvpn-client
    fi
    # start service
    if [[ ${execute} -ne 0 ]] ; then
    	systemctl status openvpn-client 1>/dev/null 2>&1 && systemctl stop openvpn-client && logInfo 1 "${func} Stopped openvpn-client"
    	systemctl start openvpn-client && logInfo 1 "${func} Started openvpn-client"
    	systemctl status openvpn-client
    fi
    logInfo 1 "${func} completed successfully"
}
logdir=`make_temp_dir ".$(basename "${this}" .sh)"`
logDebug 1 "${this} Making temp dir ${logdir}"
mkdir -p "${logdir}"
