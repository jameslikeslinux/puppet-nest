class nest::role::workstation::chrome (
  String  $google_api_key,
  String  $google_oauth_id,
  String  $google_oauth_secret,
  Boolean $chromium = true,
) {
  case $facts['osfamily'] {
    'Gentoo': {
      if $chromium {
        nest::lib::package_use { 'www-client/chromium':
          use => 'widevine',
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
            CHROMIUM_FLAGS="\${CHROMIUM_FLAGS} --enable-gpu-rasterization"
            CHROMIUM_FLAGS="\${CHROMIUM_FLAGS} --enable-oop-rasterization"
            CHROMIUM_FLAGS="\${CHROMIUM_FLAGS} --ignore-gpu-blocklist"

            # Workaround issue with dark Gtk theme detection
            # See: https://bugs.chromium.org/p/chromium/issues/detail?id=998903
            # See: https://wiki.archlinux.org/title/chromium#Dark_mode
            CHROMIUM_FLAGS="\${CHROMIUM_FLAGS} --force-dark-mode --enable-features=WebUIDarkMode"

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

        package { 'www-client/google-chrome':
          ensure => absent,
        }
      } else {
        $chrome_wrapper = @("WRAPPER")
          #!/bin/bash
          exec /opt/google/chrome/google-chrome --enable-gpu-rasterization --force-dark-mode --enable-features=WebUIDarkMode "$@"
          | WRAPPER

        package { 'www-client/google-chrome':
          ensure => installed,
        }
        ->
        file { '/usr/bin/google-chrome-stable':
          mode    => '0755',
          owner   => 'root',
          group   => 'root',
          content => $chrome_wrapper,
        }

        package { [
          'www-client/chromium',
          'www-plugins/chrome-binary-plugins',
        ]:
          ensure => absent,
        }
        ->
        file { '/etc/chromium':
          ensure => absent,
          force  => true,
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