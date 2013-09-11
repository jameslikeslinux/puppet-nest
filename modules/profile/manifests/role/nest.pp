class profile::role::nest {
    class { 'nfs::server': }

    package_use { 'media-libs/chromaprint':
        use     => 'tools',
        version => '>=0.7',
    }

    portage::package { 'media-sound/picard':
        ensure  => installed,
        require => Package_use['media-libs/chromaprint'],
    }
}
