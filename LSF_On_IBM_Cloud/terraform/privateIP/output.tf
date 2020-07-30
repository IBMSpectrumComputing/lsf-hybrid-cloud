# -----------------------------------
#  Copyright IBM Corp. 2020. All rights reserved.
#  US Government Users Restricted Rights - Use, duplication or disclosure
#  restricted by GSA ADP Schedule Contract with IBM Corp.
# -----------------------------------

output "master" {
  value = ibm_is_instance.master[*].name
}

output "master_private_ips" {
  value = [
    for idx in range(var.master_nodes) :
    "${element(ibm_is_instance.master[*].primary_network_interface[0].primary_ipv4_address, idx)}"
  ]
}

output "worker_private_ips" {
  value = [
    for idx in range(var.worker_nodes) :
    "${element(ibm_is_instance.worker[*].primary_network_interface[0].primary_ipv4_address, idx)}"
  ]
}

output "allhosts" {
  value = join("\n", concat(local.master_hostlist, local.worker_hostlist))
}
