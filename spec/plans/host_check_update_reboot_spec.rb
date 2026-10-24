require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'nest::host::check_update_reboot' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-reboot-plan-spec-') }
  let(:parameters) do
    {
      'target' => 'fixture-host', 'hostname' => 'fixture-host',
      'transaction' => 'fixture-report', 'release' => "sha256:#{'a' * 64}",
      'output_dir' => '/supervisor/reports',
    }
  end
  let(:command) { 'nest reset reboot fixture-report --plan --format=json' }
  let(:context) { parameters.reject { |key, _value| key == 'target' } }
  let(:receipt) do
    {
      'transaction' => parameters['transaction'], 'release' => parameters['release'],
      'hostname' => parameters['hostname'], 'readback_verified' => true,
      'read_only' => true, 'reboot_eligible' => true, 'reboot_reason' => 'eligible',
      'execution_requested' => false, 'acceptance_recorded' => false,
    }
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

  ['eligible', 'already_requested', 'already_booted'].each do |reason|
    it "retains #{reason} without execute, reconnect, acceptance or preparation" do
      calls = []
      expect_task('nest::retain_update_reboot').with_params(context.merge('action' => 'check')).return do |targets:, **_options|
        calls << 'check'
        Bolt::ResultSet.new(targets.map { |target| Bolt::Result.new(target, value: { 'destination_checked' => true }) })
      end
      expect_command(command).with_targets('fixture-host').return do |targets:, **_options|
        calls << 'plan'
        Bolt::ResultSet.new(targets.map { |target| Bolt::Result.for_command(target, { 'stdout' => '{}', 'stderr' => '', 'exit_code' => 0 }, 'command', command, []) })
      end
      expect_task('nest::retain_update_reboot').with_targets('localhost').with_params(context.merge('action' => 'retain', 'report' => '{}')).return do |targets:, **_options|
        calls << 'retain'
        value = receipt.merge('reboot_eligible' => reason == 'eligible', 'reboot_reason' => reason)
        Bolt::ResultSet.new(targets.map { |target| Bolt::Result.new(target, value: value) })
      end

      result = run_plan('nest::host::check_update_reboot', parameters)

      expect(result.ok?).to be(true)
      expect(result.value['reboot_eligible']).to eq(reason == 'eligible')
      expect(result.value['execution_requested']).to be(false)
      expect(calls).to eq(['check', 'plan', 'retain'])
    end
  end

  it 'refuses a missing supervisor destination before contacting the host' do
    expect_task('nest::retain_update_reboot').with_params(context.merge('action' => 'check')).error_with('kind' => 'fixture', 'msg' => 'Missing destination')
    expect_command(command).not_be_called

    expect(run_plan('nest::host::check_update_reboot', parameters).ok?).to be(false)
  end

  it 'does not retry a native refusal or publish a fabricated report' do
    expect_task('nest::retain_update_reboot').with_params(context.merge('action' => 'check')).always_return('destination_checked' => true)
    expect_command(command).always_return(exit_code: 3, stderr: 'Unsafe identity')
    expect_task('nest::retain_update_reboot').with_params(context.merge('action' => 'retain', 'report' => '{}')).not_be_called

    expect(run_plan('nest::host::check_update_reboot', parameters).ok?).to be(false)
  end

  [
    { 'readback_verified' => false }, { 'transaction' => 'other' }, { 'hostname' => 'other' },
    { 'release' => "sha256:#{'b' * 64}" }, { 'read_only' => false }, { 'execution_requested' => true },
    { 'acceptance_recorded' => true }, { 'reboot_eligible' => nil }, { 'reboot_reason' => 'unknown' },
    { 'reboot_reason' => 'already_requested' }, { 'reboot_eligible' => false }
  ].each do |change|
    it "refuses an unbound or contradictory receipt #{change.inspect}" do
      expect_task('nest::retain_update_reboot').with_params(context.merge('action' => 'check')).always_return('destination_checked' => true)
      expect_command(command).always_return(stdout: '{}')
      expect_task('nest::retain_update_reboot').with_params(context.merge('action' => 'retain', 'report' => '{}')).always_return(receipt.merge(change))

      result = run_plan('nest::host::check_update_reboot', parameters)

      expect(result.ok?).to be(false)
      expect(result.value.kind).to eq('nest/update-reboot-plan-retention')
    end
  end

  [[], ['fixture-host', 'other'], ['fixture-console'], ['fixture-console.example']].each do |targets|
    it "rejects unsupported targets #{targets.inspect} before host contact" do
      expect_task('nest::retain_update_reboot').not_be_called
      expect_command(command).not_be_called

      expect(run_plan('nest::host::check_update_reboot', parameters.merge('target' => targets)).ok?).to be(false)
    end
  end
end
