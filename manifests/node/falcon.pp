class nest::node::falcon {
  nest::lib::toolchain {
    [
      'aarch64-unknown-linux-gnu',
      'armv7a-unknown-linux-gnueabihf',
    ]:
      # use defaults
    ;

    'arm-none-eabi':
      gcc_only => true,
    ;
  }

  # Export GitLab SSH key hosted on this node
  if $facts['gitlab_ssh'] {
    $facts['gitlab_ssh'].each |$key, $value| {
      @@sshkey { "[falcon.nest]:2222@${value['type']}":
        key => $value['key'],
      }
    }
  }
}
