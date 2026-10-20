# Bounded informational publication only. No full application activation.
class nest::service::joyride_info {
  if $nest::kubernetes::service != 'joyride-info' or $nest::kubernetes::namespace != 'joyride-info' {
    fail('Joyride informational resources require service and namespace joyride-info')
  }
  if lookup('joyride_info_image') !~ /^registry\.eyrie\/joy\/joyride-info@sha256:[0-9a-f]{64}$/ {
    fail('Joyride informational deployment requires an immutable static-only image')
  }
}
