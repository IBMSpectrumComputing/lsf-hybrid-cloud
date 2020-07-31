#!/bin/bash
# -----------------------------------
#  Copyright IBM Corp. 2020. All rights reserved.
#  US Government Users Restricted Rights - Use, duplication or disclosure
#  restricted by GSA ADP Schedule Contract with IBM Corp.
# -----------------------------------
#
# Description: functions for logging and debug
#

verbose=${verbose:-1}
debug=${debug:-0}
use_color=${use_color:-1}
OFF="[0m"

timeStamp() {
    date "+%Y-%m-%d-%H:%M:%S"
    return
}
msg() {
    local color=${1:-${OFF}}
    if [[ "${use_color}" -eq 0 ]]; then
	color=${OFF}
    fi
    if [ "${1}" != "" ]; then shift;fi
    local prefix=${1:-""}    
    if [ "${1}" != "" ]; then shift;fi
    color=`color "${color}"`
    echo "`timeStamp`${color} ${prefix}[0m $@"
}
color() {
    local func="${FUNCNAME[0]}()"
    local color=${1:-"off"}
    case "${color}" in
	'blue')
	    echo "[34;01m"
	    return 0
	    ;;
	'cyan')
	    echo "[36;01m"
	    return 0
	    ;;
	'cyann')
	    echo "[36m"
	    return 0
	    ;;    
	'green')
	    echo "[32;01m"
	    return 0
	    ;;
	'red')
	    echo "[31;01m"
	    return 0
	    ;;
	'purp'|'purple')
	    echo "[35;01m"
	    return 0
	    ;;
	'off')
	    echo "[0m"
	    return 0
	    ;;
	'yellow')
	    echo "[33;01m"
	    return 0
	    ;;
    esac
    echo ""
}
logDebug() {
    local level=${1:-0}
    shift
    if ((level > debug)); then
	return 0
    fi
    local prefix=`printf "%-6s" "DEBUG${level}"`
    msg "cyann" "${prefix}" $@
    
}
logError()  {
    local prefix=`printf "%-6s" "ERROR"`    
    msg "red" "${prefix}" $@ >&2
}
logWarn() {
    local prefix=`printf "%-6s" "WARN"`
    msg "blue" "${prefix}" $@
}
logInfo() {
    local level=${1:-0}
    shift
    if ((level > verbose)); then
	return 0
    fi
    local prefix=`printf "%-6s" "INFO${level}"`
    local color="off"
    case ${level} in
	1) color="yellow";;
	2) color="cyan";;
    esac
    msg "${color}" "${prefix}" $@
}
