class makeconf (
    $buildpkg  = false,
    $getbinpkg = false,
    $makejobs  = $processorcount + 1,
    $use       = [],
) {
    if $getbinpkg {
        portage::makeconf { 'portage_binhost':
            content => $getbinpkg,
        }
    }

    $features = [
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
}
