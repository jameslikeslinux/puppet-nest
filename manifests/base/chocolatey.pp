class nest::base::chocolatey {
  include chocolatey

  chocolateyfeature { 'useRememberedArgumentsForUpgrades':
    ensure => enabled,
  }

  # Chocolatey must be installed and configured before packages
  Class['nest::base::chocolatey']
  -> Package <| provider == 'chocolatey' or provider == undef |>
}
