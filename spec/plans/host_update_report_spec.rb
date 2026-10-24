require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'nest::host::update_report' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-report-plan-spec-') }
  let(:parameters) do
    {
      'target' => 'fixture-host', 'hostname' => 'fixture-host',
      'transaction' => 'fixture-report', 'release' => "sha256:#{'a' * 64}",
      'output_dir' => '/supervisor/reports',
    }
  end
  let(:command) { 'nest reset report fixture-report --format=json' }
  let(:context) { parameters.reject { |key, _value| key == 'target' } }
  let(:receipt) do
    {
      'id' => parameters['transaction'], 'release' => parameters['release'],
      'hostname' => parameters['hostname'], 'readback_verified' => true,
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

  it 'transports report stdout to the supervisor task with exact expected bindings' do
    expect_task('nest::retain_update_report').with_params(context.merge('action' => 'check')).always_return('destination_valid' => true)
    expect_command(command).with_targets('fixture-host').always_return(stdout: '{"fixture":"sanitized report"}')
    expect_task('nest::retain_update_report').with_targets('localhost').with_params(
      'report' => '{"fixture":"sanitized report"}', 'transaction' => 'fixture-report',
      'release' => "sha256:#{'a' * 64}", 'hostname' => 'fixture-host', 'output_dir' => '/supervisor/reports'
    ).always_return(receipt)

    result = run_plan('nest::host::update_report', parameters)

    expect(result.ok?).to be(true)
    expect(result.value['readback_verified']).to be(true)
  end

  it 'does not publish or replay when the remote export fails' do
    expect_task('nest::retain_update_report').with_params(context.merge('action' => 'check')).always_return('destination_valid' => true)
    expect_command(command).always_return(exit_code: 3, stderr: 'Missing shared state')
    expect_task('nest::retain_update_report').with_params(context.merge('report' => '{}')).not_be_called

    expect(run_plan('nest::host::update_report', parameters).ok?).to be(false)
  end

  it 'fails when supervisor publication or validation fails' do
    expect_task('nest::retain_update_report').with_params(context.merge('action' => 'check')).always_return('destination_valid' => true)
    expect_command(command).always_return(stdout: '{}')
    expect_task('nest::retain_update_report').with_params(context.merge('report' => '{}')).error_with('kind' => 'nest/update-report', 'msg' => 'Publication refused')

    expect(run_plan('nest::host::update_report', parameters).ok?).to be(false)
  end

  it 'checks the supervisor destination before contacting the host' do
    calls = []
    expect_task('nest::retain_update_report').with_params(context.merge('action' => 'check')).return do |targets:, **_options|
      calls << 'check'
      Bolt::ResultSet.new(targets.map { |target| Bolt::Result.new(target, value: { 'destination_checked' => true }) })
    end
    expect_command(command).return do |targets:, **_options|
      calls << 'export'
      Bolt::ResultSet.new(targets.map { |target| Bolt::Result.for_command(target, { 'stdout' => '{}', 'stderr' => '', 'exit_code' => 0 }, 'command', command, []) })
    end
    expect_task('nest::retain_update_report').with_params(context.merge('report' => '{}')).return do |targets:, **_options|
      calls << 'retain'
      Bolt::ResultSet.new(targets.map { |target| Bolt::Result.new(target, value: receipt) })
    end

    expect(run_plan('nest::host::update_report', parameters).ok?).to be(true)
    expect(calls).to eq(['check', 'export', 'retain'])
  end

  it 'refuses an invalid context or destination before remote export' do
    expect_task('nest::retain_update_report').with_params(context.merge('action' => 'check')).error_with(
      'kind' => 'nest/update-report', 'msg' => 'Destination refused',
    )
    expect_command(command).not_be_called

    expect(run_plan('nest::host::update_report', parameters).ok?).to be(false)
  end

  [
    { 'readback_verified' => false },
    { 'readback_verified' => nil },
    { 'id' => 'other-transaction' },
    { 'release' => "sha256:#{'b' * 64}" },
    { 'hostname' => 'other-host' },
  ].each do |change|
    it "refuses an unbound retention receipt #{change.inspect} without repeating export" do
      exports = []
      expect_task('nest::retain_update_report').with_params(context.merge('action' => 'check')).always_return('destination_valid' => true)
      expect_command(command).return do |targets:, **_options|
        exports << command
        Bolt::ResultSet.new(targets.map { |target| Bolt::Result.for_command(target, { 'stdout' => '{}', 'stderr' => '', 'exit_code' => 0 }, 'command', command, []) })
      end
      expect_task('nest::retain_update_report').with_params(context.merge('report' => '{}')).always_return(receipt.merge(change))

      result = run_plan('nest::host::update_report', parameters)

      expect(result.ok?).to be(false)
      expect(result.value.kind).to eq('nest/update-report-retention')
      expect(exports).to eq([command])
    end
  end

  it 'rejects multiple targets before any export' do
    expect_command(command).not_be_called
    expect_task('nest::retain_update_report').not_be_called

    expect(run_plan('nest::host::update_report', parameters.merge('target' => ['fixture-host', 'other'])).ok?).to be(false)
  end
end
