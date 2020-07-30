#!/bin/bash
# -----------------------------------
#  Copyright IBM Corp. 2020. All rights reserved.
#  US Government Users Restricted Rights - Use, duplication or disclosure
#  restricted by GSA ADP Schedule Contract with IBM Corp.
# -----------------------------------
#
# 2020-06-16 Marc Dombrowa
# Setup OpenVPN Sever in IBM Cloud VPC instance

# verbosity 
export verbose=${verbose:-1}
# debug 
export debug=${debug:-0}

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
# provide vars to the sourced script below
export thisdir=${thisdir}
source "${thisdir}/vpn_functions.sh" $@
#
## main
#
server_setup
logInfo 1 "${this} exiting"
