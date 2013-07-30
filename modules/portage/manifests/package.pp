# = Define: portage::package
#
# Configures and install portage backed packages
#
# == Parameters
#
# [*ensure*]
#
# The ensure value of the package.
#
# [*use*]
#
# Use flags for the package.
#
# [*keywords*]
#
# Portage keywords for the package.
#
# [*target*]
#
# A default value for package.* targets
#
# [*use_target*]
#
# An optional custom target for package use flags
#
# [*keywords_target*]
#
# An optional custom target for package keywords
#
# [*mask_target*]
#
# An optional custom target for package masks
#
# [*unmask_target*]
#
# An optional custom target for package unmasks
#
# [*use_version*]
#
# An optional version specification for package use
#
# [*keywords_version*]
#
# An optional version specification for package keywords
#
# [*mask*]
#
# An optional version specification for package mask
#
# [*unmask*]
#
# An optional version specification for package unmask
#
# == Example
#
#     portage::package { 'app-admin/puppet':
#       ensure   => '3.0.1',
#       use      => ['augeas', '-rrdtool'],
#       keywords => '~amd64',
#       target   => 'puppet',
#       mask     => '<=2.7.18',
#     }
#
# == See Also
#
#  * `puppet describe package_use`
#  * `puppet describe package_keywords`
#  * `puppet describe package_mask`
#  * `puppet describe package_unmask`
#
define portage::package (
    $ensure           = undef,
    $use              = undef,
    $use_version      = undef,
    $keywords         = undef,
    $keywords_version = undef,
    $mask             = undef,
    $unmask           = undef,
    $target           = undef,
    $use_target       = undef,
    $keywords_target  = undef,
    $mask_target      = undef,
    $unmask_target    = undef,
) {

  if $use_target {
    $assigned_use_target = $use_target
  }
  else {
    $assigned_use_target = $target
  }

  if $keywords_target {
    $assigned_keywords_target = $keywords_target
  }
  else {
    $assigned_keywords_target = $target
  }

  if $mask_target {
    $assigned_mask_target = $mask_target
  }
  else {
    $assigned_mask_target = $target
  }

  if $unmask_target {
    $assigned_unmask_target = $unmask_target
  }
  else {
    $assigned_unmask_target = $target
  }

  if $keywords or $keywords_version {
    if $keywords == 'all' {
      $assigned_keywords = undef
    }
    else {
      $assigned_keywords = $keywords
    }
    package_keywords { $name:
      keywords => $assigned_keywords,
      version  => $keywords_version,
      target   => $assigned_keywords_target,
      notify   => [Exec["rebuild_${name}"], Package[$name]],
    }
  }

  if $unmask {
    if $unmask == 'all' {
      $assigned_unmask = undef
    }
    else {
      $assigned_unmask = $unmask
    }
    package_unmask { $name:
      version => $assigned_unmask,
      target  => $assigned_unmask_target,
      notify  => [Exec["rebuild_${name}"], Package[$name]],
    }
  }

  if $mask {
    if $mask == 'all' {
      $assigned_mask = undef
    }
    else {
      $assigned_mask = $mask
    }
    package_mask { $name:
      version => $assigned_mask,
      target  => $assigned_mask_target,
      notify  => [Exec["rebuild_${name}"], Package[$name]],
    }
  }

  if $use {
    package_use { $name:
      use     => $use,
      version => $use_version,
      target  => $assigned_use_target,
      notify  => [Exec["rebuild_${name}"], Package[$name]],
    }
  }

  exec { "rebuild_${name}":
    command     => "/usr/bin/emerge --changed-use -u1 ${name}",
    refreshonly => true,
    timeout     => 43200,
  }

  package { $name:
    ensure => $ensure,
  }
}
