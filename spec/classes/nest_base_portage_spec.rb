require 'spec_helper'

describe 'nest::base::portage' do
  let(:pre_condition) { 'include nest' }

  on_supported_os.each do |os, facts|
    case os
    when %r{^gentoo-}
      context 'on Gentoo' do
        let(:facts) do
          facts
        end

        let(:post_condition) do
          <<~PP
          package { 'foo/bar':
            ensure => installed,
          }
          PP
        end

        it { is_expected.to contain_portage__makeconf('features').that_requires('Class[nest::base::distcc]') }
        it { is_expected.to contain_class('nest::base::portage').that_comes_before('Package[foo/bar]') }
      end
    end
  end
end
