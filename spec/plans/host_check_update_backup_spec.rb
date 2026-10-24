require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'nest::host::check_update_backup' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-check-backup-spec-') }
  let(:check) do
    { 'kind' => 'hermes', 'target' => 'fixture-backup', 'user' => 'joy', 'backup_dir' => '/fixture/backups',
      'checkpoint' => 'fixture', 'expected_sha256' => 'c' * 64, 'max_age_seconds' => 3600,
      'required_profiles' => ['talon'], 'hold_id' => 'release-fixture' }
  end
  let(:retention) do
    { 'transaction' => 'fixture', 'release' => "sha256:#{'a' * 64}", 'hostname' => 'fixture-host',
      'policy_sha256' => 'b' * 64, 'stage' => 'preflight', 'output_dir' => '/fixture/reports' }
  end
  let(:params) { { 'check' => check, 'retention' => retention } }
  let(:receipt) { { 'verification_retained' => true, 'hold_checked' => true, 'readback_verified' => true } }
  let(:native_params) { check.reject { |key, _value| key == 'kind' }.merge('action' => 'check-hold', 'release' => retention['release']) }

  def modulepath
    [plan_modulepath, File.expand_path('../fixtures/modules', __dir__)]
  end

  around :each do |example|
    File.symlink(File.expand_path('../..', __dir__), File.join(plan_modulepath, 'nest'))
    example.run
  ensure
    FileUtils.remove_entry(plan_modulepath)
  end

  before :each do
    allow_any_command.not_be_called
    expect_plan('nest::app::hermes::backup').not_be_called
  end

  def native_result
    target = Bolt::Target.new('fixture-backup')
    Bolt::ResultSet.new([Bolt::Result.for_command(target, { 'stdout' => 'native observation', 'stderr' => '', 'exit_code' => 0 }, 'command', 'fixture', [])])
  end

  it 'checks supervisor destination before the single native observation, then retains exact stdout' do
    checked = false
    expect_task('nest::retain_update_backup').with_targets('localhost').with_params('action' => 'check', 'check' => check, 'retention' => retention).return do |targets:, **_options|
      checked = true
      Bolt::ResultSet.new(targets.map { |target| Bolt::Result.for_task(target, '{}', '', 0, 'nest::retain_update_backup', []) })
    end
    expect_plan('nest::app::hermes::retain_generation').with_params(native_params).be_called_times(1).return do |**_options|
      expect(checked).to be(true)
      Bolt::PlanResult.new(native_result, 'success')
    end
    expect_task('nest::retain_update_backup').with_targets('localhost').with_params(
      'action' => 'retain', 'check' => check, 'retention' => retention, 'report' => 'native observation',
    ).always_return(receipt)
    result = run_plan('nest::host::check_update_backup', params)
    expect(result.ok?).to be(true)
    expect(result.value).to eq(receipt)
  end

  it 'refuses a missing hold before remote observation or supervisor publication' do
    expect_task('nest::retain_update_backup').not_be_called
    expect_plan('nest::app::hermes::retain_generation').not_be_called
    check.delete('hold_id')
    expect(run_plan('nest::host::check_update_backup', params).ok?).to be(false)
  end

  it 'refuses a bad supervisor destination before contacting backup storage' do
    expect_task('nest::retain_update_backup').with_params(
      'action' => 'check', 'check' => check, 'retention' => retention,
    ).error_with('kind' => 'fixture/path', 'msg' => 'Missing destination')
    expect_plan('nest::app::hermes::retain_generation').not_be_called
    expect(run_plan('nest::host::check_update_backup', params).ok?).to be(false)
  end

  it 'propagates a missing or busy native hold without retry or publication' do
    allow_task('nest::retain_update_backup').with_params('action' => 'check', 'check' => check, 'retention' => retention).always_return({})
    expect_plan('nest::app::hermes::retain_generation').with_params(native_params).be_called_times(1).error_with('kind' => 'fixture/hold', 'msg' => 'Missing hold')
    expect_task('nest::retain_update_backup').with_params(
      'action' => 'retain', 'check' => check, 'retention' => retention, 'report' => 'native observation',
    ).not_be_called
    expect(run_plan('nest::host::check_update_backup', params).ok?).to be(false)
  end

  ['verification_retained', 'hold_checked', 'readback_verified'].each do |key|
    it "refuses absent #{key} even after native success" do
      allow_task('nest::retain_update_backup').with_params('action' => 'check', 'check' => check, 'retention' => retention).always_return({})
      expect_plan('nest::app::hermes::retain_generation').with_params(native_params).return do |**_options|
        Bolt::PlanResult.new(native_result, 'success')
      end
      expect_task('nest::retain_update_backup').with_params(
        'action' => 'retain', 'check' => check, 'retention' => retention, 'report' => 'native observation',
      ).always_return(receipt.reject { |field, _value| field == key })
      expect(run_plan('nest::host::check_update_backup', params).ok?).to be(false)
    end
  end
end
