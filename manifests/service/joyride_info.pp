# Bounded informational publication only. No full application activation.
class nest::service::joyride_info {
  if $nest::kubernetes::service != 'joyride-info' or $nest::kubernetes::namespace != 'joyride-info' {
    fail('Joyride informational resources require service and namespace joyride-info')
  }

  $server_base64 = base64('encode', file('nest/app/joyride/informational_site.py'))
  $server_sha256 = sha256(file('nest/app/joyride/informational_site.py'))
  $bundle_0      = base64('encode', file('nest/app/joyride/informational/bundle-0.json'))
  $bundle_1      = base64('encode', file('nest/app/joyride/informational/bundle-1.json'))
  $bundle_sha256 = sha256([file('nest/app/joyride/informational/bundle-0.json'), file('nest/app/joyride/informational/bundle-1.json')].join(''))
}
