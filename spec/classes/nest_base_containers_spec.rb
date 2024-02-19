require 'spec_helper'

describe 'nest::base::containers' do
  let(:pre_condition) { 'include nest' }

  on_supported_os.each do |os, facts|
    case os
    when %r{^gentoo-}
      context 'on Gentoo' do
        let(:facts) do
          facts
        end

        it { is_expected.to contain_file('/etc/subuid').that_requires('Class[nest::base::users]') }
        it { is_expected.to contain_file('/etc/subgid').that_requires('Class[nest::base::users]') }
      end
    end
  end
end
