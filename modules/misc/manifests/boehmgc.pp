class misc::boehmgc {
    #
    # Sweet...I love when Portage doesn't work...
    #
    # required by dev-scheme/guile-2.0.11
    # required by sys-devel/autogen-5.17.4
    # required by net-libs/gnutls-3.3.6
    # required by net-misc/openconnect-6.00[gnutls]
    # required by kde-misc/networkmanagement-0.9.0.11[openconnect]
    # required by kde-base/solid-runtime-4.13.3[networkmanager]
    # required by kde-base/kdebase-runtime-meta-4.13.3
    # required by kde-base/kdebase-startkde-4.11.11
    # required by kde-base/kdebase-meta-4.13.3
    # required by @selected
    # required by @world (argument)
    # >=dev-libs/boehm-gc-7.4.2 threads
    #
    # AND
    #
    # required by dev-scheme/guile-2.0.11
    # required by sys-devel/autogen-5.17.4
    # required by net-libs/gnutls-3.3.6
    # required by app-admin/rsyslog-7.6.3-r1[ssl]
    # required by @selected
    # required by @world (argument)
    # >=dev-libs/boehm-gc-7.4.2 threads
    package_use { 'dev-libs/boehm-gc':
        use => 'threads',
    }
}
