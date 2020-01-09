class nest::profile::base::bootloader {
  case $::nest::bootloader {
    systemd: { contain 'nest::profile::base::bootloader::systemd' }
    default: { contain 'nest::profile::base::bootloader::grub' }
  }
}
