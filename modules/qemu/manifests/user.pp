class qemu::user {
    package_use { [
        'sys-libs/zlib',
        'dev-libs/glib',
    ]:
        use    => 'static-libs',
        before => Portage::Package['app-emulation/qemu-user'],
    }

    #
    # XXX: 1.4.0 needs LIBS="-Wl,-Bstatic -lrt" to compile successfully
    #
    portage::package { 'app-emulation/qemu-user':
        ensure  => installed,
    }
}
