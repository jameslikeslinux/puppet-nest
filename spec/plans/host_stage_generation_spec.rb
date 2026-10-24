require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'nest::host::stage_generation' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-plan-spec-') }
  let(:policy) { { 'hostname' => 'fixture-host' } }
  let(:report) do
    { 'kind' => 'nest_generation_transfer_report', 'schema' => 1, 'policy' => policy,
      'read_only' => true, 'sealed' => false, 'reset_authorized' => false }
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

  def command(check)
    "python3 /usr/libexec/nest/transfer-generation.py '#{policy.to_json}'#{check ? ' --check' : ''}"
  end

  it 'defaults to exact inventory-backed read-only admission' do
    expect_command(command(true)).with_targets('fixture-host').always_return('stdout' => report.to_json)
    result = run_plan('nest::host::stage_generation', 'targets' => 'fixture-host', 'policy' => policy)

    expect(result.ok?).to be(true)
    expect(result.value).to eq(report)
  end

  it 'requires explicit check=false to invoke the transfer path' do
    transferred = report.merge('read_only' => false, 'sealed' => true)
    expect_command(command(false)).with_targets('fixture-host').always_return('stdout' => transferred.to_json)
    result = run_plan('nest::host::stage_generation', 'targets' => 'fixture-host', 'policy' => policy, 'check' => false)

    expect(result.ok?).to be(true)
    expect(result.value).to eq(transferred)
  end

  ['other', 'fixture-host.nest', 'fixture-console', 'fixture-console.nest', 'control1.nest'].each do |name|
    it "refuses nonmatching or excluded inventory scope #{name} before any command" do
      allow_any_command.not_be_called
      result = run_plan('nest::host::stage_generation', 'targets' => name, 'policy' => policy)

      expect(result.ok?).to be(false)
    end
  end

  it 'refuses multiple targets before any command' do
    allow_any_command.not_be_called
    result = run_plan('nest::host::stage_generation', 'targets' => ['fixture-host', 'other'], 'policy' => policy)

    expect(result.ok?).to be(false)
  end

  ['fixture-console', 'fixture-console.nest', 'control1.nest'].each do |name|
    it "refuses excluded name #{name} even when the supplied policy agrees" do
      allow_any_command.not_be_called
      result = run_plan('nest::host::stage_generation', 'targets' => name, 'policy' => policy.merge('hostname' => name))

      expect(result.ok?).to be(false)
    end
  end

  [
    { 'sealed' => true },
    { 'read_only' => false },
    { 'policy' => { 'hostname' => 'different' } },
    { 'schema' => 2 },
    { 'reset_authorized' => true },
  ].each do |change|
    it "refuses changed or contradictory result #{change} without retry" do
      expect_command(command(true)).with_targets('fixture-host').always_return('stdout' => report.merge(change).to_json)
      result = run_plan('nest::host::stage_generation', 'targets' => 'fixture-host', 'policy' => policy)

      expect(result.ok?).to be(false)
    end
  end
end
