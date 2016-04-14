#!/bin/bash

# OpenVPN seems to run without a useful PATH
export PATH=/usr/bin:/bin

# Pass arguments as facts to Puppet
export FACTER_hosts_file="${HOSTS:-/etc/hosts}"
export FACTER_action="$1"
export FACTER_ip="$2"
export FACTER_cn="$3"

exec puppet apply --no-report --logdest syslog "$(dirname $(readlink -f "$0"))/learn-address.pp"
