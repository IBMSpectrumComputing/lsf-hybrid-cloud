# -----------------------------------
#  Copyright IBM Corp. 2020. All rights reserved.
#  US Government Users Restricted Rights - Use, duplication or disclosure
#  restricted by GSA ADP Schedule Contract with IBM Corp.
# -----------------------------------

# IBM Cloud Provider
# Docs are available here, https://cloud.ibm.com/docs/terraform?topic=terraform-tf-provider#store_credentials
# Download IBM Cloud Provider binary from release page. https://github.com/IBM-Cloud/terraform-provider-ibm/releases
# And copy it to $HOME/.terraform.d/plugins/terraform-provider-ibm_v1.2.4

variable "base_name" {}
variable "domain_name" {}
variable "zone" {}
variable "key_name" {}
variable "image_name" {}
variable "master_profile" {}
variable "worker_profile" {}
variable "login_profile" {}
variable "ssh_key_file" {}
variable "gen_files_dir" {}
variable "vpn_peer" {
  type = object({
    address = string
    psk = string
    cidrs = list(string)
    security = object({
      auth = string
      encr = string
      DH_Group = number
      ip_sec = object({
        key_lifetime = number
        PFS = string
      })
      ike = object({
        version = number
        key_lifetime = number
      })
    })
  })
}
variable "lsf_cluster_name" {}

#variable "address_prefix" {}
# variable "address_mgmt" {
#     default = "default"
# }

resource ibm_is_vpc "vpc" {
  name = "${var.base_name}-vpc"
#  address_prefix_management = var.address_mgmt
}

resource "ibm_is_public_gateway" "mygateway" {
    name = "${var.base_name}-gateway"
    vpc = ibm_is_vpc.vpc.id
    zone = var.zone

    //User can configure timeouts
    timeouts {
        create = "90m"
    }
}



# create this subnet with prefix when manual prefix mgmt is requested
# resource "ibm_is_vpc_address_prefix" "addr-prefix" {
#   name = "${var.base_name}-addr-prefix"
#   zone = var.zone
#   vpc  = ibm_is_vpc.vpc.id
#   cidr = "${var.address_prefix}"
# }
# resource ibm_is_subnet "subnet" {
#   count = "${var.address_mgmt == "manual" ? 1 : 0 }"
#   name = "${var.base_name}-subnet"
#   vpc  = ibm_is_vpc.vpc.id
#   zone = var.zone
#   total_ipv4_address_count = 256
#   public_gateway = ibm_is_public_gateway.mygateway.id
#   ipv4_cidr_block = ibm_is_vpc.addr-prefix.id
# }
# create this subnet when default prefix mgmt is requested
resource ibm_is_subnet "subnet" {
  name = "${var.base_name}-subnet"
  vpc  = ibm_is_vpc.vpc.id
  zone = var.zone
  total_ipv4_address_count = 256
  public_gateway = ibm_is_public_gateway.mygateway.id
}

resource "ibm_is_security_group" "sg" {
    name = "${var.base_name}-sg"
    vpc = ibm_is_vpc.vpc.id
}

# allow all incoming network traffic on port 22
resource "ibm_is_security_group_rule" "ingress_ssh_all" {
  group     = ibm_is_security_group.sg.id
  direction = "inbound"
#  remote    = "169.0.0.0/8"
  remote    = "0.0.0.0/0"

  tcp {
    port_min = 22
    port_max = 22
  }
}

# # OpenVPN only
# # allow all incoming network traffic on port 1194
# resource "ibm_is_security_group_rule" "ingress_vpn_all" {
#   group     = ibm_is_security_group.sg.id
#   direction = "inbound"
# #  remote    = "169.0.0.0/8"
#   remote    = "0.0.0.0/0"

#   tcp {
#     port_min = 1194
#     port_max = 1194
#   }
# }

# allow all incoming tcp network traffic in the security group
resource "ibm_is_security_group_rule" "ingress_tcp_all" {
  group     = ibm_is_security_group.sg.id
  direction = "inbound"
  remote    =  ibm_is_security_group.sg.id

  tcp {
    port_min = 1
    port_max = 65535
  }
}

# enable PING across instances
resource "ibm_is_security_group_rule" "ingress_icmp_type0" {
  group     = ibm_is_security_group.sg.id
  direction = "inbound"
  remote    =  ibm_is_security_group.sg.id
  icmp {
    type = 0
#    code = 0
  }
}
resource "ibm_is_security_group_rule" "ingress_icmp_type8" {
  group     = ibm_is_security_group.sg.id
  direction = "inbound"
  remote    =  ibm_is_security_group.sg.id
  icmp {
    type = 8
#    code = 0
  }
}

# Have to enable the outbound traffic here. Default is off
resource "ibm_is_security_group_rule" "egress_all" {
  group     = ibm_is_security_group.sg.id
  direction = "outbound"
  remote    = "0.0.0.0/0"
}


# import an existing vpc resource
#data ibm_is_vpc "vpc" {
#  name = var.resource_prefix
#}

data ibm_is_image "image" {
  name = var.image_name
}

# Key with fingerprint already exists, so can't create another key here
#resource "ibm_is_ssh_key" "ssh_key" {
#  name       = "${var.base_name}-key"
#  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC1dNA8XUy14BLYyHL243ZQCVdkFF2SmKjIORF/82muZ8hO+EEsJM+RLUiJLgFwn0QhBywLg+EskGGIcdiUCoJuoacF+bSQO4bl7pCyj/EdytPaEToSN9dKwE3wFChTmbJ1wuGdvDdqhkwBgCCJYPua2A0uJz9m88rf6kiE3dlCsvj+0tX2p9UbfsmGKlCo3wICE/aH9va6BlLG61ztRbRcjGv3MF82NUBH2lNRF6LLUf/pD7uNmnqr1B6D4qbGilqA0KjKT7f/uW2JpXqDyMBU0/GzdFJn1DezluCvRam9RkttqVR7dyHh8HGVqgzyJfvFZfnaxidniYvpBBUTmLIX hfwen@sophiamcbookpro.watson.ibm.com"
#}

data ibm_is_ssh_key "ssh_key" {
   name = var.key_name
}

# login node - only node with fip
# worker instances
resource "ibm_is_instance" "login" {
  name    = "${var.base_name}-login"
  image   = data.ibm_is_image.image.id
  profile = var.login_profile
  vpc     = ibm_is_vpc.vpc.id
  zone    = var.zone
  keys    = [data.ibm_is_ssh_key.ssh_key.id]

  # fip will be assinged
  primary_network_interface {
    name   = "eth0"
    subnet = ibm_is_subnet.subnet.id
    security_groups = [ibm_is_security_group.sg.id]
  }
}

# worker instances
resource "ibm_is_instance" "worker" {
  name    = "${var.base_name}-worker-${count.index}"
  image   = data.ibm_is_image.image.id
  profile = var.worker_profile
  vpc     = ibm_is_vpc.vpc.id
  zone    = var.zone
  keys    = [data.ibm_is_ssh_key.ssh_key.id]
  count   = var.worker_nodes

  primary_network_interface {
    name   = "eth0"
    subnet = ibm_is_subnet.subnet.id
    security_groups = [ibm_is_security_group.sg.id]
  }
}

# master instance
resource "ibm_is_instance" "master" {
  name    = "${var.base_name}-master-${count.index}"
  image   = data.ibm_is_image.image.id
  profile = var.master_profile
  vpc     = ibm_is_vpc.vpc.id
  zone    = var.zone
  keys    = [data.ibm_is_ssh_key.ssh_key.id]
  count   = var.master_nodes

  primary_network_interface {
    name   = "eth0"
    subnet = ibm_is_subnet.subnet.id
    security_groups = [ibm_is_security_group.sg.id]
  }
  # volume for nfs
  volumes = ["${element(ibm_is_volume.master_nfs.*.id, count.index)}"]
}

####DNS Settings####
data "ibm_resource_group" "rg" {
  name = "Default"
}

resource "ibm_resource_instance" "lsf-dns-instance" {
  name              = "${var.base_name}-dns"
  resource_group_id = data.ibm_resource_group.rg.id
  location          = "global"
  service           = "dns-svcs"
  plan              = "standard-dns"
}

resource "ibm_dns_zone" "lsf-test-zone" {
  name        = var.domain_name
  instance_id = ibm_resource_instance.lsf-dns-instance.guid
  description = "lsf test zone"
  label       = "${var.base_name}-dns"
}

resource "ibm_dns_permitted_network" "test-pdns-permitted-network-nw" {
  instance_id = ibm_resource_instance.lsf-dns-instance.guid
  zone_id     = ibm_dns_zone.lsf-test-zone.zone_id
  vpc_crn     = ibm_is_vpc.vpc.crn
}


#data "ibm_dns_permitted_networks" "test" {
#  depends_on = [ibm_dns_permitted_network.test-pdns-permitted-network-nw]
#  instance_id = ibm_dns_zone.test-pdns-zone.instance_id
#  zone_id = ibm_dns_zone.test-pdns-zone.zone_id
#}
#
#output "dns_permitted_nw_output" {
#  value = data.ibm_dns_permitted_networks.test.dns_permitted_networks
#}


resource "ibm_dns_resource_record" "lsf-dns-worker-record-a" {
  instance_id = ibm_resource_instance.lsf-dns-instance.guid
  zone_id     = ibm_dns_zone.lsf-test-zone.zone_id
  type        = "A"
  count       = var.worker_nodes
  name        = element(ibm_is_instance.worker[*].name, count.index)
  #count       = length(local.workers_priv) ##fixme: how to register with multiple vnics
  rdata       = element(local.workers_priv, count.index)
}

resource "ibm_dns_resource_record" "lsf-dns-master-record-a" {
  instance_id = ibm_resource_instance.lsf-dns-instance.guid
  zone_id     = ibm_dns_zone.lsf-test-zone.zone_id
  type        = "A"
  count       = var.master_nodes
  name        = element(ibm_is_instance.master[*].name, count.index)
  #count       = length(local.masters_priv) ##fixme: how to register with multiple vnics
  rdata       = element(local.masters_priv, count.index)
}

#data "ibm_dns_zones" "lsf-dns-test" {
#  depends_on = [ibm_dns_zone.lsf-test-zone]
#  instance_id = ibm_resource_instance.lsf-dns-instance.guid
#}


###### Volumes ######
resource "ibm_is_volume" "master_nfs" {
  count    = var.master_nodes
  name     = "${var.base_name}-masternfs-${count.index}-volume"
  profile  = var.volume_profile
  capacity = var.volume_capacity
  zone     = var.zone
}

###### Floating IPs ######
// For login
resource "ibm_is_floating_ip" "login_fip" {
  name   = "${var.base_name}-login-fip"
  target = ibm_is_instance.login.primary_network_interface[0].id
  lifecycle {
    ignore_changes = [resource_group]
  }
}

##### VPN #####
# z1 gateway
resource "ibm_is_vpn_gateway" "vpn_gateway" {
  name   = "${var.base_name}-vpn-gw"
  subnet = ibm_is_subnet.subnet.id
}

resource "ibm_is_ike_policy" "ike_policy" {
  name                     = "${var.base_name}-ike-policy"
  authentication_algorithm = var.vpn_peer.security.auth
  encryption_algorithm     = var.vpn_peer.security.encr
  dh_group                 = var.vpn_peer.security.DH_Group
  ike_version              = var.vpn_peer.security.ike.version
  key_lifetime             = var.vpn_peer.security.ike.key_lifetime
}

resource "ibm_is_ipsec_policy" "ipsec_policy" {
  name                     = "${var.base_name}-ipsec-policy"
  authentication_algorithm = var.vpn_peer.security.auth
  encryption_algorithm     = var.vpn_peer.security.encr
  pfs                      = var.vpn_peer.security.ip_sec.PFS
  key_lifetime             = var.vpn_peer.security.ip_sec.key_lifetime
}

# z1 connection
# resource "ibm_is_vpn_gateway_connection" "vpn_conn" {
#   name           = "${var.base_name}-vpn-conn"
#   vpn_gateway    = ibm_is_vpn_gateway.vpn_gateway.id
#   peer_address   = var.vpn_peer.address
#   preshared_key  = var.vpn_peer.psk
#   local_cidrs    = [ibm_is_subnet.subnet.ipv4_cidr_block]
#   peer_cidrs     = var.vpn_peer.cidrs
#   admin_state_up = true
# # initially setting to clear, will have to be updated once the connection is up
#   action         = "clear"
#   interval       = 15
#   timeout        = 30
# }

###################
# local variables #
###################
locals {
  workers = [
    for idx in range(var.worker_nodes) :
    "${element(ibm_is_instance.worker[*].primary_network_interface[0].primary_ipv4_address, idx)}"
  ]
  workers_priv = [
    for idx in range(var.worker_nodes) :
    "${element(ibm_is_instance.worker[*].primary_network_interface[0].primary_ipv4_address, idx)}"
  ]

  worker_hostlist = [
    for idx in range(var.worker_nodes) :
    "${element(ibm_is_instance.worker[*].primary_network_interface[0].primary_ipv4_address, idx)} ${element(ibm_is_instance.worker[*].name, idx)}"
  ]

  masters = [
    for idx in range(var.master_nodes) :
    "${element(ibm_is_instance.master[*].primary_network_interface[0].primary_ipv4_address, idx)}"
  ]
  masters_priv = [
    for idx in range(var.master_nodes) :
    "${element(ibm_is_instance.master[*].primary_network_interface[0].primary_ipv4_address, idx)}"
  ]
  master_hostlist = [
    for idx in range(var.master_nodes) :
    "${element(ibm_is_instance.master[*].primary_network_interface[0].primary_ipv4_address, idx)} ${element(ibm_is_instance.master[*].name, idx)}"
  ]
  worker_mem = "${element(ibm_is_instance.worker[*].memory, 0) * 1024}"

  gen_file_path = "${var.gen_files_dir}"
}

##############################################
# create Ansible inventory for cluster setup #
##############################################
resource "local_file" "inventory" {
  content = templatefile("${path.module}/templates/clusterinventory.tpl",
    {
      login_ip           = ibm_is_floating_ip.login_fip.address
      worker_ips         = local.workers_priv
      master_ips         = local.masters_priv
      nfs_public_ips     = ibm_is_instance.master[0].primary_network_interface[0].primary_ipv4_address
      nfs_server_ip      = ibm_is_instance.master[0].primary_network_interface[0].primary_ipv4_address
      nfs_volume_size    = ibm_is_volume.master_nfs[0].capacity
      nfs_mnt_dir        = var.volume_dir
      deployer_ip        = local.masters_priv[0]
      ssh_config         = "${var.gen_files_dir}/ssh_config"
      lsf_cluster_name   = var.lsf_cluster_name
  })
  filename        = "${local.gen_file_path}/cluster.inventory"
  file_permission = "0666"
}

resource "local_file" "clusterhosts" {
  content  = join("\n", concat(local.master_hostlist, local.worker_hostlist))
  filename = "${local.gen_file_path}/clusterhosts-${var.base_name}"
}

resource "local_file" "ssh_config" {
  content = templatefile("${path.module}/templates/ssh_config.tpl",
    {
      login_public_ip    = ibm_is_floating_ip.login_fip.address
      worker_private_ips = local.workers_priv
      master_private_ips = local.masters_priv
      local_ssh_keyfile  = var.ssh_key_file
      deployer_ip        = local.masters_priv[0]
  })
  filename        = "${local.gen_file_path}/ssh_config"
  file_permission = "0666"
}

resource "local_file" "GEN2-config" {
  content = templatefile("${path.module}/templates/GEN2-config.tpl",
    {
        g2region    = var.region
        g2zone      = var.zone
        g2vpc_id    = ibm_is_vpc.vpc.id
        g2img_id    = data.ibm_is_image.image.id
        g2sn_id     = ibm_is_subnet.subnet.id
        g2sg_id     = ibm_is_security_group.sg.id
        g2profile   = var.master_profile
        g2worker_mem = local.worker_mem
        g2dns_instance = ibm_resource_instance.lsf-dns-instance.guid
        g2dns_zone     = ibm_dns_zone.lsf-test-zone.zone_id
        g2domain_name  = var.domain_name
  })
  filename        = "${local.gen_file_path}/GEN2-cfg.yml"
  file_permission = "0666"
}

resource "local_file" "vpn_file" {
  content = templatefile("${path.module}/templates/vpn_file.tpl",
    {
        vpn_region     = var.region
        conn_name      = "${var.base_name}-vpn-conn"
        vpn_gateway    = ibm_is_vpn_gateway.vpn_gateway.id
        local_cidr     = ibm_is_subnet.subnet.ipv4_cidr_block
        vpn_peer       = var.vpn_peer
        vpn_ike_pol    = ibm_is_ike_policy.ike_policy.id
        vpn_ipsec_pol  = ibm_is_ipsec_policy.ipsec_policy.id
  })
  filename        = "${local.gen_file_path}/vpn.yml"
  file_permission = "0666"
}
