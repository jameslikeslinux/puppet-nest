class nest::firmware::opensbi {
  unless $nest::opensbi_branch {
    fail("'opensbi_branch' is not set")
  }

  # For nest::base::portage::makeopts
  include 'nest::base::portage'

  $opensbi_make_cmd = @("ZSBL_MAKE")
    #!/bin/bash
    set -ex -o pipefail
    export HOME=/root PATH=/usr/lib/distcc/bin:/usr/bin:/bin
    cd /usr/src/opensbi
    make ${nest::base::portage::makeopts} PLATFORM=generic 2>&1 | tee build.log
    | ZSBL_MAKE

  nest::lib::src_repo { '/usr/src/opensbi':
    url    => 'https://gitlab.james.tl/nest/forks/opensbi.git',
    ref    => $nest::opensbi_branch,
    notify => Exec['opensbi-build'],
  }
  ->
  file { '/usr/src/opensbi/build.sh':
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => $opensbi_make_cmd,
  }
  ~>
  exec { 'opensbi-build':
    command     => '/usr/src/opensbi/build.sh',
    noop        => !$facts['build'],
    refreshonly => true,
    timeout     => 0,
  }
}
