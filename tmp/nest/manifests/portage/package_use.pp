define nest::portage::package_use (
  $use,
) {
  package_use { $name:
    use    => $use,
    notify => Nest::Portage::Package_rebuild[$name],
  }

  if !defined(Nest::Portage::Package_rebuild[$name]) {
    nest::portage::package_rebuild { $name: }
  }

  if defined(Package[$name]) {
    Package_use[$name] ->
    Package[$name] ->
    Nest::Portage::Package_rebuild[$name]
  }
}
