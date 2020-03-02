class nest::profile::base::qemu {
  case $facts['osfamily'] {
    'Gentoo': {
      $qemu_guest_agent_ensure = $::nest::vm ? {
        true    => installed,
        default => absent,
      }

      package { 'app-emulation/qemu-guest-agent':
        ensure => $qemu_guest_agent_ensure,
      }

      if $::nest::distcc_server {
        nest::portage::package_use { [
          'dev-libs/glib',
          'sys-libs/zlib',
          'sys-apps/attr',
          'dev-libs/libpcre',
        ]:
          use => 'static-libs',
        }

        Nest::Portage::Package_use <| title == 'app-emulation/qemu' |> {
          use +> ['static-user', 'qemu_user_targets_arm'],
        }
      }
    }

    'windows': {
      package { 'virtio-drivers':
        ensure => installed,
      }
    }
  }
}
