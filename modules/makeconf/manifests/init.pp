class makeconf (
    $buildpkg  = false,
    $getbinpkg = false,
    $makejobs  = $processorcount + 1,
) {
    $buildpkg_feature = $buildpkg ? {
        true    => 'buildpkg ',
        default => '',
    }

    if $getbinpkg {
        $getbinpkg_feature = 'getbinpkg '

        portage::makeconf { 'portage_binhost':
            content => $getbinpkg,
        }
    } else {
        $getbinpkg_feature = ''
    }

    $features = [$buildpkg_feature, $getbinpkg_feature]

    portage::makeconf { 'features':
        content => join($features, ''),
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

    include makeconf::use::default
}
