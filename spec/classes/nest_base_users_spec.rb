require 'spec_helper'

describe 'nest::base::users' do
  let(:pre_condition) { 'include nest' }

  on_supported_os.each do |os, facts|
    case os
    when %r{^gentoo-}
      context 'on Gentoo' do
        let(:facts) do
          facts
        end

        it { is_expected.to contain_user('root').that_notifies('Class[nest::base::dracut]') }
      end

    when %r{^windows-}
      context 'on Windows' do
        let(:facts) do
          facts
        end

        it { is_expected.to contain_vcsrepo('C:/tools/cygwin/home/james').that_requires('Class[nest::base::cygwin]') }
      end
    end
  end
end
