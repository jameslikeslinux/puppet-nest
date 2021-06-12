#!/bin/bash
#
# PDK container wrapper
#
# Run the Puppet Development Kit container image provided by Puppet.
# See: https://hub.docker.com/r/puppet/pdk
# See: https://github.com/puppetlabs/pdk-docker
#

exec podman run --rm -it -v "$(pwd):/root" puppet/pdk "$@"
