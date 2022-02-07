Facter.add('cygwin_ssh') do
  confine osfamily: 'windows'
  setcode do
    ['dsa', 'ecdsa', 'ed25519', 'rsa'].each_with_object({}) do |id, keys|
      file = "C:/tools/cygwin/etc/ssh_host_#{id}_key.pub"
      if File.exist? file
        (type, key, _rest) = File.read(file).split(' ', 3)
        keys[id] = { key: key, type: type }
      end
    end
  end
end
