require 'spec_helper'

describe 'nest::base::gentoo' do
  let(:pre_condition) { 'include nest' }

  on_supported_os.each do |os, facts|
    case os
    when %r{^gentoo-}
      context 'on Gentoo' do
        let(:facts) do
          facts
        end

        it { is_expected.to contain_exec('eselect-news-read').that_requires('Class[nest::base::mta]') }
      end
    end
  end
end
