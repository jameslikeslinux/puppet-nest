class nest::role::workstation::chromium (
  String $google_api_key,
  String $google_oauth_id,
  String $google_oauth_secret,
) {
  case $facts['osfamily'] {
    'Gentoo': {
      nest::lib::package_use { 'www-client/chromium':
        use => ['-screencast', 'widevine'],
      }

      unless $facts['build'] == 'stage1' {
        package { 'www-client/chromium':
          ensure => installed,
        }

        if $facts['architecture'] == 'amd64' {
          package { 'www-plugins/chrome-binary-plugins':
            ensure => installed,
          }
        }

        $xdg_session_type = '$XDG_SESSION_TYPE'
        $chromium_flags = @("EOT"/$)
          [[ $xdg_session_type == 'x11' ]] && CHROMIUM_FLAGS="\${CHROMIUM_FLAGS} --force-device-scale-factor=${::nest::gui_scaling_factor} --enable-use-zoom-for-dsf"
          CHROMIUM_FLAGS="\${CHROMIUM_FLAGS} --disable-smooth-scrolling"
          CHROMIUM_FLAGS="\${CHROMIUM_FLAGS} --enable-gpu-rasterization"
          CHROMIUM_FLAGS="\${CHROMIUM_FLAGS} --enable-oop-rasterization"
          CHROMIUM_FLAGS="\${CHROMIUM_FLAGS} --ignore-gpu-blocklist"

          # For Sync and other Google services
          # See: https://www.gentoo.org/support/news-items/2021-08-11-oauth2-creds-chromium.html
          export GOOGLE_API_KEY='${google_api_key}'
          export GOOGLE_DEFAULT_CLIENT_ID='${google_oauth_id}'
          export GOOGLE_DEFAULT_CLIENT_SECRET='${google_oauth_secret}'
          | EOT

        file { '/etc/chromium/nest':
          mode    => '0644',
          owner   => 'root',
          group   => 'root',
          content => $chromium_flags,
          require => Package['www-client/chromium'],
        }
      }
    }

    'windows': {
      package { 'googlechrome':
        ensure => installed,
      }
    }
  }
}
