require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'nest::host::update_manager_health' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-manager-health-spec-') }

  def modulepath
    [plan_modulepath, File.expand_path('../fixtures/modules', __dir__)]
  end

  around :each do |example|
    File.symlink(File.expand_path('../..', __dir__), File.join(plan_modulepath, 'nest'))
    example.run
  ensure
    FileUtils.remove_entry(plan_modulepath)
  end

  it 'returns the observation without claiming transaction acceptance' do
    expect_task('nest::update_manager_health').with_targets('fixture-host').always_return(
      'result' => 'pass', 'acceptance_recorded' => false,
    )

    result = run_plan('nest::host::update_manager_health', 'target' => 'fixture-host')

    expect(result.ok?).to be(true)
    expect(result.value['acceptance_recorded']).to be(false)
  end

  it 'preserves an unavailable manager result rather than treating transport success as health' do
    expect_task('nest::update_manager_health').always_return(
      'result' => 'fail', 'user_managers' => { 'availability' => 'unavailable' },
    )

    result = run_plan('nest::host::update_manager_health', 'target' => 'fixture-host')

    expect(result.ok?).to be(true)
    expect(result.value['result']).to eq('fail')
    expect(result.value['user_managers']['availability']).to eq('unavailable')
  end

  it 'fails on unavailable transport or task execution' do
    expect_task('nest::update_manager_health').error_with('kind' => 'nest/unavailable', 'msg' => 'Unavailable')

    expect(run_plan('nest::host::update_manager_health', 'target' => 'fixture-host').ok?).to be(false)
  end

  it 'rejects multiple targets before running any observation' do
    expect_task('nest::update_manager_health').not_be_called

    expect(run_plan('nest::host::update_manager_health', 'target' => ['one', 'two']).ok?).to be(false)
  end
end
