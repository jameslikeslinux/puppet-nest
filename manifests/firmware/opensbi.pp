class nest::firmware::opensbi {
  unless $nest::opensbi_branch {
    fail("'opensbi_branch' is not set")
  }

  nest::lib::src_repo { '/usr/src/opensbi':
    url => 'https://gitlab.james.tl/nest/forks/opensbi.git',
    ref => $nest::opensbi_branch,
  }
  ~>
  nest::lib::build { 'opensbi':
    args => 'PLATFORM=generic BUILD_INFO=y',
    dir  => '/usr/src/opensbi',
  }
}
