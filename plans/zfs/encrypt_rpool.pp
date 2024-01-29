# Snapshot and migrate ROOT to encrypted dataset
#
# @param targets Hosts to encrypt
# @param keylocation Path to the key location on the node or 'prompt'
plan nest::zfs::encrypt_rpool (
  TargetSpec $targets,
  Variant[Stdlib::Unixpath, Enum['prompt']] $keylocation = 'prompt',
) {
  if $keylocation == 'prompt' {
    $passphrase = prompt('Encryption passphrase', 'sensitive' => true)

    if $passphrase.unwrap.length < 8 {
      fail('Passphrase must be at least 8 characters long')
    }

    if prompt('Encryption passphrase (again)', 'sensitive' => true).unwrap != $passphrase.unwrap {
      fail('Passphrases do not match')
    }

    $echo_passphrase = "echo ${passphrase.unwrap.shellquote} | "
    $keylocation_arg = $keylocation
  } else {
    $echo_passphrase = ''
    $keylocation_arg = "file://${keylocation}"
  }

  parallelize(get_targets($targets)) |$t| {
    $zfs_snapshot_cmd = "zfs snapshot -r ${t}@encrypt"
    run_command($zfs_snapshot_cmd, $t, 'zfs snapshot', {
      '_run_as' => 'root',
    })

    $zfs_create_cmd = "${echo_passphrase}zfs create -o encryption=aes-128-gcm \
                        -o keyformat=passphrase -o keylocation=${keylocation_arg} ${t}/crypt"
    run_command($zfs_create_cmd, $t, "zfs create ${t}/crypt", {
      '_run_as' => 'root',
    })

    run_command("zfs create -o atime=off ${t}/crypt/ROOT", $t, "zfs create ${t}/crypt/ROOT", {
      '_run_as' => 'root',
    })

    $current_fs = run_command("zfs list -H -o name \$(findmnt -n -o SOURCE /)", $t, 'Get current BE', {
      '_run_as' => 'root',
    }).first.value['stdout'].chomp.regsubst('^.*?/', '')

    $datasets = {
      $current_fs           => '-o canmount=noauto -o mountpoint=/',
      "${current_fs}/debug" => '-o canmount=noauto -o mountpoint=/usr/lib/debug -o compression=zstd',
      "${current_fs}/src"   => '-o canmount=noauto -o mountpoint=/usr/src -o compression=zstd',
      "${current_fs}/var"   => '-o canmount=noauto -o mountpoint=/var',
      'home'                => '-o canmount=noauto -o mountpoint=/home',
      'home/james'          => '-o canmount=noauto -o mountpoint=/home/james',
      'swap'                => '-o refreservation=none',
    }

    $datasets.each |$fs, $opts| {
      $zfs_move_cmd = "zfs send -v ${t}/${fs}@encrypt | zfs receive -v ${opts} ${t}/crypt/${fs}"
      run_command($zfs_move_cmd, $t, "zfs send/receive ${t}/${fs}", {
        '_run_as' => 'root',
      })
    }

    $zfs_set_canmount_cmd = "zfs set -r canmount=noauto ${t}/${current_fs}"
    run_command($zfs_set_canmount_cmd, $t, "Disable old BE ${t}/${current_fs}", {
      '_run_as' => 'root',
    })

    $swaplabel_cmd = "swaplabel -L '' ${t}/swap"
    run_command($swaplabel_cmd, $t, "Disable old swap", {
      '_run_as' => 'root',
    })

    $zpool_set_bootfs_cmd = "zpool set bootfs=${t}/crypt/${current_fs} ${t}"
    run_command($zfs_move_cmd, $t, 'zpool set bootfs', {
      '_run_as' => 'root',
    })
  }
}
