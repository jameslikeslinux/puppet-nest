Facter.add('bitwarden_installed') do
  setcode do
    File.exist? '/srv/bitwarden/bwdata/env/global.override.env'
  end
end
