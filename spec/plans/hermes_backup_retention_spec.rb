require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'nest::app::hermes::backup verification retention' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-plan-spec-') }
  let(:retention) do
    { 'transaction' => 'fixture', 'release' => "sha256:#{'a' * 64}", 'hostname' => 'fixture-host',
      'policy_sha256' => 'b' * 64, 'stage' => 'preflight', 'output_dir' => '/fixture' }
  end
  let(:params) do
    { 'target' => 'fixture-backup', 'backup_dir' => '/private/fixture', 'verify_only' => true,
      'expected_sha256' => 'c' * 64, 'max_age_seconds' => 3600, 'checkpoint' => 'fixture',
      'required_profiles' => ['talon'], 'verification_retention' => retention }
  end
  let(:check) do
    params.reject { |key, _value| ['verify_only', 'verification_retention'].include?(key) }.merge('kind' => 'hermes', 'user' => 'joy')
  end

  def modulepath
    [plan_modulepath, File.expand_path('../fixtures/modules', __dir__)]
  end

  around :each do |example|
    File.symlink(File.expand_path('../..', __dir__), File.join(plan_modulepath, 'nest'))
    example.run
  ensure
    FileUtils.remove_entry(plan_modulepath)
  end

  it 'checks the destination before any host command or helper upload' do
    task_params = { 'action' => 'check', 'check' => check, 'retention' => retention }
    expect_task('nest::retain_update_backup').with_targets('localhost').with_params(task_params).error_with('kind' => 'nest/update-backup-retention', 'msg' => 'Missing destination')
    allow_any_command.not_be_called
    expect_upload('nest/hermes-backup-generation').not_be_called

    expect(run_plan('nest::app::hermes::backup', params).ok?).to be(false)
  end

  it 'retains native stdout with the exact resolved backup target and returns only the supervisor receipt' do
    checked = false
    expect_task('nest::retain_update_backup').with_params('action' => 'check', 'check' => check, 'retention' => retention).return do |targets:, **_options|
      checked = true
      Bolt::ResultSet.new(targets.map { |target| Bolt::Result.for_task(target, '{}', '', 0, 'nest::retain_update_backup', []) })
    end
    expect_command('mktemp /tmp/nest-hermes-backup-generation.XXXXXXXX').with_targets('fixture-backup').return do |targets:, command:, **_options|
      expect(checked).to be(true)
      Bolt::ResultSet.new(targets.map { |target| Bolt::Result.for_command(target, { 'stdout' => '/fixture/helper', 'stderr' => '', 'exit_code' => 0 }, 'command', command, []) })
    end
    allow_any_command.return do |targets:, command:, **_options|
      expect(command).to include('podman unshare /fixture/helper verify')
      Bolt::ResultSet.new(targets.map { |target| Bolt::Result.for_command(target, { 'stdout' => 'native verification', 'stderr' => '', 'exit_code' => 0 }, 'command', command, []) })
    end
    expect_upload('nest/hermes-backup-generation').with_targets('fixture-backup').with_destination('/fixture/helper')
    receipt = { 'path' => '/fixture/retained.json', 'verification_retained' => true, 'readback_verified' => true }
    expect_task('nest::retain_update_backup').with_params('action' => 'retain', 'check' => check, 'retention' => retention, 'report' => 'native verification').always_return(receipt)

    result = run_plan('nest::app::hermes::backup', params)
    expect(result.ok?).to be(true)
    expect(result.value).to eq(receipt)
  end

  it 'does not retry native verification when supervisor retention fails' do
    expect_task('nest::retain_update_backup').with_params('action' => 'check', 'check' => check, 'retention' => retention)
    expect_command('mktemp /tmp/nest-hermes-backup-generation.XXXXXXXX').always_return('stdout' => '/fixture/helper')
    allow_any_command.always_return('stdout' => 'native verification').be_called_times(1)
    expect_upload('nest/hermes-backup-generation').with_targets('fixture-backup').with_destination('/fixture/helper')
    task_params = { 'action' => 'retain', 'check' => check, 'retention' => retention, 'report' => 'native verification' }
    expect_task('nest::retain_update_backup').with_params(task_params).error_with('kind' => 'nest/update-backup-retention', 'msg' => 'Retention failed')

    expect(run_plan('nest::app::hermes::backup', params).ok?).to be(false)
  end

  it 'refuses retention on capture before any host command' do
    allow_any_command.not_be_called
    expect_task('nest::retain_update_backup').not_be_called

    expect(run_plan('nest::app::hermes::backup', params.merge('verify_only' => false)).ok?).to be(false)
  end
end
