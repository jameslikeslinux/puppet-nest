class makeconf {
    $makejobs = $processorcount + 1

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

    makeconf::use { 'default': }
}
