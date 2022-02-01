Facter.add('gitlab_ssh') do
  setcode do
    ['ecdsa', 'ed25519', 'rsa'].each_with_object({}) do |id, keys|
      file = "/srv/gitlab/config/ssh_host_#{id}_key.pub"
      if File.exist? file
        (type, key, _rest) = File.read(file).split(' ', 3)
        keys[id] = { key: key, type: type }
      end
    end
  end
end
