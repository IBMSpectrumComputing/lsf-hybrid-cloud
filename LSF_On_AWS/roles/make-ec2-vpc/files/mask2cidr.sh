#!/bin/bash
#-----------------------------------
# Copyright IBM Corp. 1992, 2017. All rights reserved.
# US Government Users Restricted Rights - Use, duplication or disclosure
# restricted by GSA ADP Schedule Contract with IBM Corp.
#-----------------------------------

# Function calculates number of bit in a netmask
#  See: https://www.linuxquestions.org/questions/programming-9/bash-cidr-calculator-646701/
# For original source of mask2cidr function
mask2cidr() {
    nbits=0
    IFS=.
    for dec in $1 ; do
        case $dec in
            255) let nbits+=8;;
            254) let nbits+=7;;
            252) let nbits+=6;;
            248) let nbits+=5;;
            240) let nbits+=4;;
            224) let nbits+=3;;
            192) let nbits+=2;;
            128) let nbits+=1;;
            0);;
            *) echo "Error: $dec is not recognised"; exit 1
        esac
    done
    echo "$nbits"
}

NET=$1
MASK=$2
if [ -z $MASK ]; then
    echo "Provide a subnet mask for conversion"
    exit 1
fi

bcnt=$(mask2cidr $MASK)
echo "${NET}/${bcnt}"
exit 0

