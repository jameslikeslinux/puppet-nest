require 'puppet/provider/sshkey/parsed'

Puppet::Type.type(:sshkey).provide(:cygwin, parent: :parsed) do
  confine    :operatingsystem => :windows
  defaultfor :operatingsystem => :windows

  # Copied from https://github.com/puppetlabs/puppetlabs-sshkeys_core/blob/main/lib/puppet/provider/sshkey/parsed.rb
  text_line :comment, match: %r{^#}
  text_line :blank, match: %r{^\s*$}
  record_line :parsed, fields: ['name', 'type', 'key'],
                       post_parse: proc { |hash|
                                     names = hash[:name].split(',', -1)
                                     hash[:name] = names.shift
                                     hash[:host_aliases] = names
                                   },
                       pre_gen: proc { |hash|
                                  if hash[:host_aliases]
                                    hash[:name] = [hash[:name], hash[:host_aliases]].flatten.join(',')
                                    hash.delete(:host_aliases)
                                  end
                                }

  def self.default_target
    'C:/tools/cygwin/etc/ssh_known_hosts'
  end
end
