# = Class: portage
#
# Configure the Portage package management system
#
# == Parameters
#
# [*make_conf*]
#
# The path to make.conf.
#
# As of 2012-09-09 new systems will use /etc/portage/make.conf, but on older
# systems this can be /etc/make.conf.
#
# == Example
#
#     class { 'portage':
#       $make_conf = '/etc/portage/make.conf',
#     }
#
# == See Also
#
#  * emerge(1) http://dev.gentoo.org/~zmedico/portage/doc/man/emerge.1.html
#  * make.conf(5) http://dev.gentoo.org/~zmedico/portage/doc/man/make.conf.5.html

class portage (
  $make_conf = $portage::params::make_conf,
) inherits portage::params {

  include concat::setup

  file {
    '/etc/portage/package.keywords':
      ensure  => directory;
    '/etc/portage/package.mask':
      ensure  => directory;
    '/etc/portage/package.unmask':
      ensure  => directory;
    '/etc/portage/package.use':
      ensure  => directory;
    '/etc/portage/postsync.d':
      ensure  => directory;
  }

  exec { 'changed_makeconf_use':
    command     => '/usr/bin/emerge --changed-use --deep @world',
    refreshonly => true,
    timeout     => 43200,
  }

  concat { $make_conf:
    owner  => root,
    group  => root,
    mode   => 644,
    notify => Exec['changed_makeconf_use'],
  }

  concat::fragment { 'makeconf_header':
    target  => $make_conf,
    content => template('portage/makeconf.header.conf.erb'),
    order   => 00,
  }
}
