class nest::unifi_video_revproxy (
  Optional[Variant[String[1], Array[String[1]]]] $ip = undef,
) {
  nest::revproxy { 'unifi-video':
    servername    => 'heloandnala.net',
    destination   => 'http://unifi.cams/',
    websockets    => '/ws/',
    serveraliases => ['www.heloandnala.net'],
    ip            => $ip,
    preserve_host => true,
  }

  nest::revproxy { 'unifi-video-default-port':
    servername    => 'heloandnala.net',
    destination   => 'http://unifi.cams/',
    websockets    => '/ws/',
    ip            => $ip,
    port          => 7443,
    preserve_host => true,
  }

  nest::revproxy { 'unifi-video-video':
    servername    => 'heloandnala.net',
    destination   => 'http://unifi.cams:7445/',
    websockets    => '/',
    ip            => $ip,
    port          => 7446,
  }
}
