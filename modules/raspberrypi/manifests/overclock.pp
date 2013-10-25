class raspberrypi::overclock (
    $setting,
) {
    case $setting {
        modest: {
            $arm_freq     = 800
            $core_freq    = 300
            $sdram_freq   = 400
            $over_voltage = 0
        }

        medium: {
            $arm_freq     = 900
            $core_freq    = 333
            $sdram_freq   = 450
            $over_voltage = 2
        }

        high: {
            $arm_freq     = 950
            $core_freq    = 450
            $sdram_freq   = 450
            $over_voltage = 6
        }

        turbo: {
            $arm_freq     = 1000 
            $core_freq    = 500
            $sdram_freq   = 500
            $over_voltage = 6
        }

        default: {
            fail('Overclock setting must be one of: modest, medium, high, turbo')
        }
    }

    raspberrypi::config { 'arm_freq':
        value => $arm_freq,
    }

    raspberrypi::config { 'core_freq':
        value => $core_freq,
    }

    raspberrypi::config { 'sdram_freq':
        value => $sdram_freq,
    }

    raspberrypi::config { 'over_voltage':
        value => $over_voltage,
    }
}
