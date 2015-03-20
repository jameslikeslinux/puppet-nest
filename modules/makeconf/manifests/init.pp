class makeconf (
    $debug     = false,
    $buildpkg  = false,
    $getbinpkg = false,
    $distcc    = false,
#    $makejobs  = $processorcount + 1,
    $makejobs  = 2,
    $use       = [],
    $overlays  = [],
) {
    if $getbinpkg {
        portage::makeconf { 'portage_binhost':
            content => $getbinpkg,
        }
    }

    $features = [
        $debug ? {
            false   => [],
            default => 'splitdebug',
        },

        $distcc ? {
            false   => [],
            default => 'distcc',
        },

        $buildpkg ? {
            false   => [],
            default => 'buildpkg',
        },

        $getbinpkg ? {
            false   => [],
            default => 'getbinpkg',
        },
    ]

    if $debug and $portage_cflags !~ /-ggdb/ {
        $cflags = "${portage_cflags} -ggdb"
    } else {
        $cflags = $portage_cflags
    }

    portage::makeconf { 'features':
        content => join(flatten($features), ' '),
    }

    portage::makeconf { 'makeopts':
        content => "-j${makejobs}",
    }

    portage::makeconf { 'cflags':
        content => $cflags,
    }

    portage::makeconf { 'cxxflags':
        content => $cflags,
    }

    portage::makeconf { 'accept_license':
        content => '*',
    }

    # This is completely unnecessary, but done for completeness
    $usestring = join($use, ' ')
    $usestring_cpuflags = "${usestring} ${portage_cpu_flags_x86}"
    $usestring_cpuflags_sorted = join(sort(split($usestring_cpuflags, ' ')), ' ')

    portage::makeconf { 'use':
        content => $usestring_cpuflags_sorted,
    }

    unless $overlays == [] {
        portage::makeconf { 'portdir_overlay':
            content => join($overlays),
        }
    }

    if $portage_cpu_flags_x86 {
        portage::makeconf { 'cpu_flags_x86':
            content => $portage_cpu_flags_x86,
        }
    }
}
