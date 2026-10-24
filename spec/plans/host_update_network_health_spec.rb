require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'nest::host::update_network_health' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-network-health-spec-') }
  let(:endpoints) { [{ 'hostname' => 'service.example', 'addresses' => ['192.0.2.1'], 'path' => '/readyz', 'status' => 200 }] }

  def modulepath
    [plan_modulepath, File.expand_path('../fixtures/modules', __dir__)]
  end

  around :each do |example|
    File.symlink(File.expand_path('../..', __dir__), File.join(plan_modulepath, 'nest'))
    example.run
  ensure
    FileUtils.remove_entry(plan_modulepath)
  end

  it 'passes exact policy without root escalation and preserves failed observations' do
    expect_task('nest::update_network_health').with_targets('fixture-host').with_params(
      'endpoints' => endpoints,
    ).always_return('result' => 'fail', 'acceptance_recorded' => false)

    result = run_plan('nest::host::update_network_health', 'target' => 'fixture-host', 'endpoints' => endpoints)

    expect(result.ok?).to be(true)
    expect(result.value).to include('result' => 'fail', 'acceptance_recorded' => false)
  end

  it 'fails on unavailable transport or task execution' do
    expect_task('nest::update_network_health').error_with('kind' => 'nest/unavailable', 'msg' => 'Unavailable')

    expect(run_plan('nest::host::update_network_health', 'target' => 'fixture-host', 'endpoints' => endpoints).ok?).to be(false)
  end

  it 'rejects multiple targets before running any observation' do
    expect_task('nest::update_network_health').not_be_called

    expect(run_plan('nest::host::update_network_health', 'target' => ['one', 'two'], 'endpoints' => endpoints).ok?).to be(false)
  end
end
