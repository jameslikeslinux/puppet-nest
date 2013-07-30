Puppet Gentoo Portage Module
============================

Provides Gentoo Portage features for Puppet.

Travis Test status: [![Build
Status](https://travis-ci.org/adrienthebo/puppet-portage.png?branch=master)](https://travis-ci.org/adrienthebo/puppet-portage)

## /etc/portage/package.\*/\*

### package\_use

    package_use { 'app-admin/puppet':
      use     => ['flag1', 'flag2'],
      target  => 'puppet-flags',
      version => '>=3.0.1',
      ensure  => present,
    }

use can be either a string or an array of strings.

### package\_keywords

    package_keywords { 'app-admin/puppet':
      keywords => ['~x86', '-hppa'],
      target   => 'puppet',
      version  => '>=3.0.1',
      ensure   => present,
    }

keywords can be either a string or an array of strings.

### package\_unmask

    package_unmask { 'app-admin/puppet':
      target  => 'puppet',
      version => '>=3.0.1',
      ensure  => present,
    }

### package\_mask

    package_mask { 'app-admin/puppet':
      target  => 'tree',
      version => '>=3.0.1',
      ensure  => present,
    }

## make.conf

The default location of make.conf is /etc/portage/make.conf
If you want to change it, you should do the following:

    class { 'portage':
      make_conf = '/etc/make.conf',
    }

In order to add entries to make.conf:

    portage::make_conf { 'use':
      content => 'flag1 flag2',
      ensure  => present,
    }
    portage::make_conf { 'portdir_overlay':
      content => '/var/lib/layman',
      ensure  => present,
    }

Changes in the USE variable will also trigger re-emerge of the affected packages.

## portage::package

This module provides a wrapper to the native package type:

    portage::package { 'app-admin/puppet':
      use              => ['-minimal', 'augeas'],
      use_version      => '>=3.0.1',
      keywords         => ['~amd64', '~x86'],
      keywords_version => '>=3.0.1',
      mask             => '<=2.3.17',
      unmask           => '>=3.0.1',
      target           => 'puppet',
      target_keywords  => 'puppet-keywords',
      ensure           => '3.0.1',
    }

If no target\_{keywords,use,mask,unmask} is specified, then the value of target
is being used.  The variables keywords, mask and unmask also accept the special
value 'all', that will create versionless entries.  (This applies only to
portage::package, if you want versionless entries in any of the above
package\_\* types, you can just omit the version attribute.) Any change in
portage::package will also trigger the appropriate re-emerge to the affected
package.

## facts

All make.conf variables and most of the eselect modules are shown by facter

## eselect

The eselect type/provider checks for the current state of an eselect module by
reading the variable of the equivalent fact.

    eselect { 'ruby':
      set => 'ruby19',
    }

For eselect modules that have submodules (eg php):

    eselect { 'php_apache2':
      set => 'php5.3',
    }

See Also
--------

  * man 5 portage: http://www.linuxmanpages.com/man5/portage.5.php
  * man 5 ebuild: http://www.linuxmanpages.com/man5/ebuild.5.php

Contributors
============

  * [Lance Albertson](https://github.com/ramereth)
  * [Russell Haering](https://github.com/russellhaering)
  * [Adrien Thebo](https://github.com/adrienthebo)
  * [Theo Chatzimichos](https://github.com/tampakrap)
  * [John-John Tedro](https://github.com/udoprog)
