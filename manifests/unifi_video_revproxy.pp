class nest::unifi_video_revproxy (
  Optional[Variant[String[1], Array[String[1]]]] $ip = undef,
) {
  nest::revproxy { 'unifi-video':
    servername    => 'video.heloandnala.net',
    destination   => 'http://unifi.video.home/',
    websockets    => '/ws/',
    serveraliases => ['heloandnala.net', 'www.heloandnala.net'],
    ip            => $ip,
    preserve_host => true,
  }

  nest::revproxy { 'unifi-video-default-port':
    servername    => 'video.heloandnala.net',
    destination   => 'http://unifi.video.home/',
    websockets    => '/ws/',
    ip            => $ip,
    port          => 7443,
    preserve_host => true,
  }

  nest::revproxy { 'unifi-video-video':
    servername    => 'video.heloandnala.net',
    destination   => 'http://unifi.video.home:7445/',
    websockets    => '/',
    ip            => $ip,
    port          => 7446,
  }
}
