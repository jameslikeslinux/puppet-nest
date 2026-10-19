require 'spec_helper'

# Resolve support must remain dormant without losing the re-enable catalog.
describe 'nest::app::resolve' do
  on_supported_os.each do |os, facts|
    next unless os.match?(%r{^gentoo-})

    context 'on Osprey' do
      let(:facts) { facts.merge(profile: { variant: 'mobile' }) }
      let(:pre_condition) { 'include nest include nest::host::osprey' }

      context 'while shelved by default' do
        it { is_expected.to compile.with_all_deps }
        it { is_expected.not_to contain_exec('build-resolve-startup-bridge') }
        it { is_expected.to contain_nest__lib__package('x11-libs/startup-notification').with_ensure('installed') }

        [
          '/usr/local/share/applications/com.blackmagicdesign.resolve.desktop',
          '/usr/local/bin/resolve-startup-bridge',
          '/usr/local/share/resolve/startup-bridge.c',
          '/etc/alsa/resolve.conf',
        ].each do |path|
          it { is_expected.to contain_file(path).with_ensure('absent') }
        end
      end

      context 'when deliberately re-enabled' do
        let(:params) { { ensure: 'present' } }
        # RSpec resource-style declaration must precede any include of this class.
        let(:pre_condition) { "include nest nest::lib::package { 'x11-libs/startup-notification': ensure => installed }" }

        it { is_expected.to compile.with_all_deps }
        it { is_expected.to contain_exec('build-resolve-startup-bridge').that_requires('File[/usr/local/share/resolve/startup-bridge.c]') }
        it { is_expected.to contain_file('/usr/local/share/applications/com.blackmagicdesign.resolve.desktop').that_requires('Exec[build-resolve-startup-bridge]') }
        it { is_expected.to contain_file('/usr/local/share/applications/com.blackmagicdesign.resolve.desktop').that_requires('File[/etc/alsa/resolve.conf]') }
      end
    end
  end
end
