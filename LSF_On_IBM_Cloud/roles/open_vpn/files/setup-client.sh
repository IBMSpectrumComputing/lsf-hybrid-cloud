#!/bin/bash
# -----------------------------------
#  Copyright IBM Corp. 2020. All rights reserved.
#  US Government Users Restricted Rights - Use, duplication or disclosure
#  restricted by GSA ADP Schedule Contract with IBM Corp.
# -----------------------------------
#
# 2020-06-30 Marc Dombrowa
# Setup OpenVPN client on-premise

print_settings=0

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
source "${thisdir}/vpn_functions.sh" $@
#
## main
#
setup_client
logInfo 1 "${this} exiting"
