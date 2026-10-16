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

        it 'uses the provider identity shim for the dotfiles command and read guard' do
          remote = catalogue.resource('Exec', 'set-dotfiles-remote-C:/tools/cygwin/home/joy')
          expect(remote[:command]).to include('/usr/local/bin/git')
          expect(remote[:unless]).to include('/usr/local/bin/git')
          expect(remote[:command]).not_to include('/usr/bin/git')
          expect(remote[:unless]).not_to include('/usr/bin/git')
          expect(remote[:user]).to be_nil
        end

        it do
          is_expected.to contain_class('nest::base::git').that_comes_before('Exec[set-dotfiles-remote-C:/tools/cygwin/home/joy]')
        end

        it 'sets the Git home after switching the Cygwin identity' do
          wrapper = catalogue.resource('File', 'C:/tools/cygwin/usr/local/bin/git')[:content]
          expect(wrapper).to match(%r{Process::Sys.setuid\('joy'\).*ENV\['HOME'\] = '/home/joy'.*exec '/bin/git', \*ARGV}m)
        end

        it 'keeps refresh on the user-switching entry point with a Cygwin home' do
          refresh = catalogue.resource('Exec', 'refresh-C:/tools/cygwin/home/joy')
          expect(refresh[:command]).to include('/home/joy/.refresh', 'HOME=')
          expect(refresh[:command]).not_to include('C:/tools/cygwin/home/joy/.refresh')
        end
      end
    end
  end
end
