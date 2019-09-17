class nest::unifi_protect_revproxy (
  Optional[Variant[String[1], Array[String[1]]]] $ip = undef,
) {
  Nest::Revproxy {
    extra_params => {
      'setenv' => [
        'proxy-initial-not-pooled 1',
      ],
    }
  }

  nest::revproxy { 'unifi-protect':
    servername    => 'video.thesatelliteoflove.net',
    destination   => 'http://unifi.protect.home:7080/',
    serveraliases => ['heloandnala.net', 'www.heloandnala.net'],
    ip            => $ip,
    preserve_host => true,
  }
}
