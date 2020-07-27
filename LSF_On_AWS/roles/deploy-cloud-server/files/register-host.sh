#!/bin/sh

. /opt/ibm/lsfsuite/lsf/conf/profile.lsf

MYIP=`ip addr |grep 'inet ' |grep eth0 |awk '{ print $2 }' |awk -F '/' '{ print $1 }'`
HNAME=`hostname`

echo "$MYIP $HNAME" > /root/hostregsetup

lsreghost -s /root/hostregsetup

exit 0
