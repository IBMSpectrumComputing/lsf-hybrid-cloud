---

# Generated settings based on terraform results
region: "${vpn_region}"
conn_name: "${conn_name}"
vpn_gateway: "${vpn_gateway}"
local_cidr: "${local_cidr}"

# pre-filled data from tf_inventory
# make sure the peer (on-prem VPN), preshared_key, and cidrs are correct
peer_address: "${vpn_peer.address}"
preshared_key: "${vpn_peer.psk}"
${yamlencode({
peer_cidrs: [for cidr in vpn_peer.cidrs : "${cidr}"],
})}

action: "restart"
interval: 10
timeout: 50
${yamlencode({ security: vpn_peer.security })}

# reference to security policies. Pre-filled with terraformed policies
# If above policy settings don't match your VPN, update the policy settings and
# comment out these lines to create new policies.
ike_pol_id: ${vpn_ike_pol}
ipsec_pol_id: ${vpn_ipsec_pol}

##################################
# OpenVPN Settings (optional)
peer_nic: <on-prem vpn interface name>
ovpn_cidr: <cidr for the subnet between OpenVPN server/client>

# End OpenVPN Settings
##################################

# If a VPN-Connection is created, there will be an ansible-managed block below this line