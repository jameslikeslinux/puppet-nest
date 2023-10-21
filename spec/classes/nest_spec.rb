require 'spec_helper'

describe 'nest' do
  let(:params) do
    {
      'pw_hash'          => 'fake-pw-hash',
      'ssh_private_keys' => {
        'ed25519' => 'fake-ssh-key',
      },
    }
  end

  it { is_expected.to compile }
end
