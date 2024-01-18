require 'spec_helper'

describe 'nest' do
  let(:params) do
    {
      'pw_hash' => 'fake-pw-hash',
      'ssh_host_keys' => {
        'example.com' => 'ed25519 fake-ssh-key',
      },
      'ssh_private_keys' => {
        'ed25519' => 'fake-ssh-key',
      },
    }
  end

  it { is_expected.to compile }
end
