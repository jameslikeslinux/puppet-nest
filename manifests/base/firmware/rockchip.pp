class nest::base::firmware::rockchip (
  String $git_branch = 'rockchip',
) {
  vcsrepo { '/usr/src/rkbin':
    ensure   => latest,
    provider => git,
    source   => 'https://gitlab.james.tl/nest/forks/rkbin.git',
    revision => $git_branch,
  }
}
