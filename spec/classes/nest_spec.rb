require 'spec_helper'

describe 'nest' do
  stage1 = [
    'nest::base::eyaml',
    'nest::base::firewall',
    'nest::base::git',
    'nest::base::openvpn',
    'nest::base::packages',
    'nest::base::puppet',
    'nest::base::qemu',
    'nest::base::ssh',
    'nest::base::syslog',
    'nest::base::users',
    'nest::base::vmware',
    'nest::base::bird',
    'nest::base::branding',
    'nest::base::cli',
    'nest::base::console',
    'nest::base::containers',
    'nest::base::distcc',
    'nest::base::distccd',
    'nest::base::fail2ban',
    'nest::base::fs',
    'nest::base::gentoo',
    'nest::base::hosts',
    'nest::base::locale',
    'nest::base::mta',
    'nest::base::network',
    'nest::base::portage',
    'nest::base::scripts',
    'nest::base::sudo',
    'nest::base::systemd',
    'nest::base::timesyncd',
    'nest::base::wifi',
    'nest::base::zfs',
  ]

  stage2 = [
    'nest::base::dracut',
    'nest::base::firmware',
    'nest::base::fstab',
    'nest::base::kernel',
    'nest::base::plymouth',
  ]

  stage3 = [
    'nest::base::bootloader',
    'nest::base::kexec',
  ]

  windows = [
    'nest::base::eyaml',
    'nest::base::firewall',
    'nest::base::git',
    'nest::base::openvpn',
    'nest::base::packages',
    'nest::base::puppet',
    'nest::base::qemu',
    'nest::base::ssh',
    'nest::base::syslog',
    'nest::base::users',
    'nest::base::vmware',
    'nest::base::cygwin',
  ]

  on_supported_os.each do |os, facts|
    case os
    when %r{^gentoo-}
      context 'on Gentoo' do
        let(:facts) do
          facts
        end

        it_should_and_should_not_contain_classes(stage1 + stage2 + stage3, windows)

        context 'when building stage1' do # rubocop:disable RSpec/EmptyExampleGroup
          let(:facts) do
            facts.merge({ build: 'stage1' })
          end

          it_should_and_should_not_contain_classes(stage1, stage2 + stage3 + windows)
        end

        context 'when building stage2' do # rubocop:disable RSpec/EmptyExampleGroup
          let(:facts) do
            facts.merge({ build: 'stage2' })
          end

          it_should_and_should_not_contain_classes(stage1 + stage2, stage3 + windows)
        end

        context 'when building stage3' do # rubocop:disable RSpec/EmptyExampleGroup
          let(:facts) do
            facts.merge({ build: 'stage3' })
          end

          it_should_and_should_not_contain_classes(stage1 + stage2 + stage3, windows)
        end
      end

    when %r{^windows-}
      context 'on Windows' do # rubocop:disable RSpec/EmptyExampleGroup
        let(:facts) do
          facts
        end

        it_should_and_should_not_contain_classes(windows, stage1 + stage2 + stage3)
      end
    end
  end
end
