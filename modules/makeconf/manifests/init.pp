class makeconf (
    $buildpkg  = false,
    $getbinpkg = false,
    $distcc    = false,
    $makejobs  = $processorcount + 1,
    $use       = [],
    $overlays  = [],
) {
    if $getbinpkg {
        portage::makeconf { 'portage_binhost':
            content => $getbinpkg,
        }
    }

    $features = [
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

    portage::makeconf { 'features':
        content => join(flatten($features), ' '),
    }

    portage::makeconf { 'makeopts':
        content => "-j${makejobs}",
    }

    portage::makeconf { 'cflags':
        content => $portage_cflags,
    }

    portage::makeconf { 'cxxflags':
        content => $portage_cxxflags,
    }

    portage::makeconf { 'accept_license':
        content => '*',
    }

    portage::makeconf { 'use':
        content => join(sort($use), ' '),
    }

    unless $overlays == [] {
        portage::makeconf { 'portdir_overlay':
            content => join($overlays),
        }
    }
}
