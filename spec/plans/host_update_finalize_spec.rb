require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'nest::host::update_finalize' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-finalize-plan-spec-') }
  let(:parameters) do
    {
      'target' => 'fixture-host', 'hostname' => 'fixture-host', 'transaction' => 'fixture-report',
      'release' => "sha256:#{'a' * 64}", 'output_dir' => '/supervisor/reports',
    }
  end
  let(:context) { parameters.reject { |key, _value| key == 'target' } }
  let(:status_command) { 'nest reset status fixture-report --format=json' }
  let(:finalize_command) { 'nest reset finalize fixture-report --cleanup=owned --format=json' }
  let(:admission) { context.merge('action' => 'admit', 'readback_verified' => true) }
  let(:receipt) { context.merge('action' => 'preview', 'readback_verified' => true, 'state' => 'accepted', 'cli_finalized' => false) }

  def modulepath
    [plan_modulepath, File.expand_path('../fixtures/modules', __dir__)]
  end

  around :each do |example|
    File.symlink(File.expand_path('../..', __dir__), File.join(plan_modulepath, 'nest'))
    example.run
  ensure
    FileUtils.remove_entry(plan_modulepath)
  end

  def expect_admission
    expect_task('nest::retain_update_finalize').with_params(context.merge('action' => 'check')).always_return('destination_checked' => true)
    expect_command(status_command).with_targets('fixture-host').always_return(stdout: 'native status')
    expect_task('nest::retain_update_finalize').with_params(context.merge('action' => 'admit', 'status' => 'native status')).always_return(admission)
  end

  it 'previews by default using retained live accepted status without mutation' do
    expect_admission
    expect_command("#{finalize_command} --plan").with_targets('fixture-host').always_return(stdout: 'native preview')
    expect_command(finalize_command).not_be_called
    expect_task('nest::retain_update_finalize').with_params(context.merge(
      'action' => 'preview', 'status' => 'native status', 'report' => 'native preview',
    )).always_return(receipt)

    result = run_plan('nest::host::update_finalize', parameters)

    expect(result.ok?).to be(true)
    expect(result.value['execution_requested']).to be(false)
    expect(result.value['admission']).to eq(admission)
  end

  it 'executes only the exact native finalization and requires finalized readback' do
    expect_admission
    expect_command(finalize_command).always_return(stdout: 'native finalized')
    expect_command("#{finalize_command} --plan").not_be_called
    expect_task('nest::retain_update_finalize').with_params(context.merge(
      'action' => 'complete', 'status' => 'native status', 'report' => 'native finalized',
    )).always_return(receipt.merge('action' => 'complete', 'state' => 'finalized', 'cli_finalized' => true))

    result = run_plan('nest::host::update_finalize', parameters.merge('execute' => true))

    expect(result.ok?).to be(true)
    expect(result.value['cli_finalized']).to be(true)
  end

  it 'refuses destination errors before any host command' do
    expect_task('nest::retain_update_finalize').with_params(context.merge('action' => 'check')).error_with('kind' => 'fixture', 'msg' => 'Missing directory')
    expect_command(status_command).not_be_called
    expect_command(finalize_command).not_be_called

    expect(run_plan('nest::host::update_finalize', parameters.merge('execute' => true)).ok?).to be(false)
  end

  it 'refuses unaccepted or changed live status before finalization' do
    expect_task('nest::retain_update_finalize').with_params(context.merge('action' => 'check')).always_return('destination_checked' => true)
    expect_command(status_command).always_return(stdout: 'not accepted')
    expect_task('nest::retain_update_finalize').with_params(context.merge('action' => 'admit', 'status' => 'not accepted')).error_with('kind' => 'fixture', 'msg' => 'Not accepted')
    expect_command(finalize_command).not_be_called

    expect(run_plan('nest::host::update_finalize', parameters.merge('execute' => true)).ok?).to be(false)
  end

  it 'does not finalize on a mismatched or missing admission readback' do
    expect_task('nest::retain_update_finalize').with_params(context.merge('action' => 'check')).always_return('destination_checked' => true)
    expect_command(status_command).always_return(stdout: 'native status')
    expect_task('nest::retain_update_finalize').with_params(context.merge('action' => 'admit', 'status' => 'native status')).always_return(admission.merge('readback_verified' => false))
    expect_command(finalize_command).not_be_called

    expect(run_plan('nest::host::update_finalize', parameters.merge('execute' => true)).ok?).to be(false)
  end

  it 'stops on ambiguous native failure without an automatic second finalization' do
    expect_admission
    expect_command(finalize_command).always_return(exit_code: 3, stderr: 'Native refusal')
    expect_task('nest::retain_update_finalize').with_params(context.merge('action' => 'complete', 'status' => 'native status', 'report' => '')).not_be_called

    expect(run_plan('nest::host::update_finalize', parameters.merge('execute' => true)).ok?).to be(false)
  end

  [
    { 'readback_verified' => false }, { 'transaction' => 'wrong' }, { 'release' => "sha256:#{'b' * 64}" },
    { 'hostname' => 'wrong' }, { 'action' => 'preview' }, { 'cli_finalized' => false }, { 'state' => 'finalizing' }
  ].each do |change|
    it "refuses an inconsistent completion receipt #{change.inspect}" do
      expect_admission
      expect_command(finalize_command).always_return(stdout: 'native finalized')
      expect_task('nest::retain_update_finalize').with_params(context.merge(
        'action' => 'complete', 'status' => 'native status', 'report' => 'native finalized',
      )).always_return(receipt.merge('action' => 'complete', 'state' => 'finalized', 'cli_finalized' => true).merge(change))

      expect(run_plan('nest::host::update_finalize', parameters.merge('execute' => true)).ok?).to be(false)
    end
  end

  ['fixture-host,other-host', 'fixture-console', 'fixture-console.example'].each do |targets|
    it "rejects an unsafe target selection #{targets}" do
      expect_task('nest::retain_update_finalize').not_be_called
      expect_command(status_command).not_be_called

      expect(run_plan('nest::host::update_finalize', parameters.merge('target' => targets)).ok?).to be(false)
    end
  end
end
