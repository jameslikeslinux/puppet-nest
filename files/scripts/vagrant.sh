#!/bin/bash
#
# Vagrant-libvirt container wrapper
# See: https://github.com/vagrant-libvirt/vagrant-libvirt#using-podman
#

mkdir -p ~/.vagrant.d/{boxes,data,tmp}

exec podman run --rm -it \
    -e LIBVIRT_DEFAULT_URI \
    -v /var/run/libvirt/:/var/run/libvirt/ \
    -v ~/.vagrant.d/boxes:/vagrant/boxes \
    -v ~/.vagrant.d/data:/vagrant/data \
    -v ~/.vagrant.d/tmp:/vagrant/tmp \
    -v $(realpath "${PWD}"):${PWD} \
    -w $(realpath "${PWD}") \
    --network host \
    --entrypoint /bin/bash \
    --security-opt label=disable \
    docker.io/vagrantlibvirt/vagrant-libvirt:latest \
    vagrant $@
