class nest::base::bootloader::uroot {
  contain 'nest::base::bootloader::spec'

  unless $nest::uroot_branch {
    fail("'uroot_branch' is not set")
  }

  nest::lib::src_repo { '/usr/src/u-root':
    url => 'https://gitlab.james.tl/nest/forks/u-root.git',
    ref => $nest::uroot_branch,
  }
  ~>
  nest::lib::build { 'uroot':
    dir     => '/usr/src/u-root',
    command => [
      'go build',
      './u-root -uinitcmd="boot" -o initramfs.cpio core boot',
    ],
  }
}
