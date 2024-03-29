#!/bin/sh
#
# run_puppet
#
# Initiate a Puppet run via systemd,
# handling environment variables as necessary
#

systemctl import-environment FACTER_build FACTER_skip_module_rebuild
systemctl restart --wait puppet-run; rc=$?
systemctl unset-environment FACTER_build FACTER_skip_module_rebuild
exit $rc
