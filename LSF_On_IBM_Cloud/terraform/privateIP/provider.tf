# -----------------------------------
#  Copyright IBM Corp. 2020. All rights reserved.
#  US Government Users Restricted Rights - Use, duplication or disclosure
#  restricted by GSA ADP Schedule Contract with IBM Corp.
# -----------------------------------

variable "region" {}
variable "apikey" {}

# Or we can switch the region via export IC_REGION="eu-gb"
provider "ibm" {
ibmcloud_api_key    = var.apikey
generation = 2
region = var.region
}
