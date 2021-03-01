class nest::base::firmware {
  case $facts['profile']['platform'] {
    'beagleboneblack': {
      contain '::nest::base::firmware::uboot'
    }

    'pinebookpro': {
      contain '::nest::base::firmware::arm'
      contain '::nest::base::firmware::uboot'

      Class['nest::base::firmware::arm']
      ~> Class['nest::base::firmware::uboot']
    }

    'raspberrypi': {
      contain '::nest::base::firmware::raspberrypi'
    }
  }
}
