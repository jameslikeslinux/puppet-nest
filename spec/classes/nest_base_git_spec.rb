require 'spec_helper'

describe 'nest::base::git' do
  let(:pre_condition) { 'include nest' }

  on_supported_os.each do |os, facts|
    case os
    when %r{^gentoo-}
      context 'on Gentoo' do
        let(:facts) do
          facts
        end

        let(:post_condition) { 'vcsrepo { "/tmp/foo": provider => git }' }

        it { is_expected.to contain_class('nest::base::git').that_comes_before('Vcsrepo[/tmp/foo]') }
      end

    when %r{^windows-}
      context 'on Windows' do
        let(:facts) do
          facts
        end

        let(:post_condition) { 'vcsrepo { "C:/Windows/Temp/foo": provider => git }' }

        it { is_expected.to contain_class('nest::base::git').that_comes_before('Vcsrepo[C:/Windows/Temp/foo]') }
      end
    end
  end
end
