require 'spec_helper'

describe 'nest::base::cygwin' do
  let(:pre_condition) { 'include nest' }

  on_supported_os.each do |os, facts|
    case os
    when %r{^windows-}
      context 'on Windows' do
        let(:facts) do
          facts
        end

        let(:post_condition) do
          <<~PP
          package { 'foo':
            ensure   => installed,
            provider => cygwin,
          }
          PP
        end

        it { is_expected.to contain_class('nest::base::cygwin').that_comes_before('Package[foo]') }
      end
    end
  end
end
