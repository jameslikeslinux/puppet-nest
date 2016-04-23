class nest::hacks::apache {
  ::apache::mod { 'log_config': }
  ::apache::mod { 'unixd': }
}
