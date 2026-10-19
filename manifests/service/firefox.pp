class nest::service::firefox {
  if defined(Class['nest::kubernetes']) {
    $bridge_token = lookup('nest::firefox_bridge_token', Sensitive).unwrap
    notice('Firefox/Kasm persistent browser is managed by KubeCM; Star control uses the owner-visible OS accessibility/UI bridge')
  }
}
