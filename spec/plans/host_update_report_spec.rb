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
    expect_command(command).with_targets('fixture-host').always_return(stdout: '{"fixture":"sanitized report"}')
    expect_task('nest::retain_update_report').with_targets('localhost').with_params(
      'report' => '{"fixture":"sanitized report"}', 'transaction' => 'fixture-report',
      'release' => "sha256:#{'a' * 64}", 'hostname' => 'fixture-host', 'output_dir' => '/supervisor/reports'
    ).always_return('readback_verified' => true)

    result = run_plan('nest::host::update_report', parameters)

    expect(result.ok?).to be(true)
    expect(result.value['readback_verified']).to be(true)
  end

  it 'does not publish or replay when the remote export fails' do
    expect_command(command).always_return(exit_code: 3, stderr: 'Missing shared state')
    expect_task('nest::retain_update_report').not_be_called

    expect(run_plan('nest::host::update_report', parameters).ok?).to be(false)
  end

  it 'fails when supervisor publication or validation fails' do
    expect_command(command).always_return(stdout: '{}')
    expect_task('nest::retain_update_report').error_with('kind' => 'nest/update-report', 'msg' => 'Publication refused')

    expect(run_plan('nest::host::update_report', parameters).ok?).to be(false)
  end

  it 'rejects multiple targets before any export' do
    expect_command(command).not_be_called
    expect_task('nest::retain_update_report').not_be_called

    expect(run_plan('nest::host::update_report', parameters.merge('target' => ['fixture-host', 'other'])).ok?).to be(false)
  end
end
