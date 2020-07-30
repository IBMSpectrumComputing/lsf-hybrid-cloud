# -----------------------------------
#  Copyright IBM Corp. 2020. All rights reserved.
#  US Government Users Restricted Rights - Use, duplication or disclosure
#  restricted by GSA ADP Schedule Contract with IBM Corp.
# -----------------------------------

variable "master_nodes" {
  default = 1
}

variable "worker_nodes" {
  default = 1
}

variable "ssh_key" {
  default = "/path/to/ssh_key"
}

# volume profile
# general-purpose   tiered
# 5iops-tier        tiered
# 10iops-tier       tiered
variable volume_profile {
  default = "general-purpose"
}

variable volume_capacity {
  default = 100
}

variable volume_dir {
  default = "/mnt/nfs"
}
