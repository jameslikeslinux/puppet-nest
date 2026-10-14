require 'spec_helper'

describe 'nest::lib::user_service' do
  let(:title) { 'timer' }
  let(:params) do
    {
      unit: 'example.timer',
      user: 'joy',
      ensure: 'running',
      enable: true,
      target: 'timers.target',
    }
  end
  let(:facts) { { is_container: true } }

  context 'in an offline image' do
    it { is_expected.to compile.with_all_deps }
    it { is_expected.not_to contain_systemd__user_service('timer') }
    it do
      is_expected.to contain_file('/home/joy/.config/systemd/user/timers.target.wants/example.timer')
        .with(ensure: 'link', target: '../example.timer')
    end

    context 'with a template instance' do
      let(:params) do
        super().merge(unit: 'example@profile.service', unit_file: 'example@.service', target: 'default.target')
      end

      it do
        is_expected.to contain_file('/home/joy/.config/systemd/user/default.target.wants/example@profile.service')
          .with(ensure: 'link', target: '../example@.service')
      end
    end

    context 'when disabled' do
      let(:params) { super().merge(enable: false, ensure: 'stopped') }

      it { is_expected.to contain_file('/home/joy/.config/systemd/user/timers.target.wants/example.timer').with_ensure('absent') }
    end
  end

  context 'on a running host' do
    let(:facts) { { is_container: false, path: '/usr/bin:/bin', systemd_version: '255' } }

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_systemd__user_service('timer').with(ensure: 'running', enable: true, user: 'joy', unit: 'example.timer') }
    it { is_expected.not_to contain_file('/home/joy/.config/systemd/user/timers.target.wants/example.timer') }
  end
end
