define nest::lib::build (
  String           $args      = '', # lint:ignore:params_empty_string_assignment
  Optional[String] $command   = undef,
  Optional[String] $defconfig = undef,
  String           $dir       = $name,
  Boolean          $distcc    = true,
  String           $makeargs  = '', # lint:ignore:params_empty_string_assignment
) {
  if $command {
    $build_command = $command
  } else {
    include 'nest::base::portage'
    $build_command = "make ${nest::base::portage::makeopts} ${makeargs} ${args}"
  }

  if $defconfig {
    file { "${dir}/.defconfig":
      mode    => '0644',
      owner   => 'root',
      group   => 'root',
      content => "${defconfig}\n",
    }
    ~>
    exec { "${name}-reset-config":
      command     => "/bin/rm -f ${dir}/.config",
      refreshonly => true,
    }
    ->
    exec { "${name}-defconfig":
      command => "/usr/bin/make ${makeargs} ${defconfig}",
      cwd     => $dir,
      creates => "${dir}/.config",
      notify  => Exec["${name}-build"],
    }
    ->
    Nest::Lib::Kconfig <| config == "${dir}/.config" |>
    ~>
    exec { "${name}-olddefconfig":
      command     => "/usr/bin/make ${makeargs} olddefconfig",
      cwd         => $dir,
      refreshonly => true,
      notify      => Exec["${name}-build"],
    }
  }

  if $distcc {
    $path = '/usr/lib/distcc/bin:/usr/bin:/bin'
  } else {
    $path = '/usr/bin:/bin'
  }

  $build_script = @("SCRIPT")
    #!/bin/bash
    set -ex -o pipefail
    export HOME=/root PATH=${path}
    cd ${dir}
    ${build_command} 2>&1 | tee build.log
    | SCRIPT

  file { "${dir}/build.sh":
    mode    => '0755',
    owner   => 'root',
    group   => 'root',
    content => $build_script,
  }
  ~>
  exec { "${name}-build":
    command     => "${dir}/build.sh",
    noop        => !$facts['build'],
    refreshonly => true,
    timeout     => 0,
  }
}
