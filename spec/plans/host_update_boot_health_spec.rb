require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'nest::host::update_boot_health' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-boot-health-spec-') }
  let(:identities) { { 'hostname' => 'fixture-host', 'kernel' => '6.18.57' } }

  def modulepath
    [plan_modulepath, File.expand_path('../fixtures/modules', __dir__)]
  end

  around :each do |example|
    File.symlink(File.expand_path('../..', __dir__), File.join(plan_modulepath, 'nest'))
    example.run
  ensure
    FileUtils.remove_entry(plan_modulepath)
  end

  it 'passes exact expectations to the root observation task without accepting a transaction' do
    expect_task('nest::update_boot_health').with_targets('fixture-host').with_params(
      'expectations' => identities, '_run_as' => 'root',
    ).always_return('result' => 'pass', 'acceptance_recorded' => false)

    result = run_plan('nest::host::update_boot_health', 'target' => 'fixture-host', 'expectations' => identities)

    expect(result.ok?).to be(true)
    expect(result.value['acceptance_recorded']).to be(false)
  end

  it 'preserves failed or unavailable observations instead of equating transport success with health' do
    expect_task('nest::update_boot_health').always_return('result' => 'fail')

    result = run_plan('nest::host::update_boot_health', 'target' => 'fixture-host', 'expectations' => identities)

    expect(result.ok?).to be(true)
    expect(result.value['result']).to eq('fail')
  end

  it 'fails when the task or transport cannot collect an observation' do
    expect_task('nest::update_boot_health').error_with('kind' => 'nest/unavailable', 'msg' => 'Unavailable')

    expect(run_plan('nest::host::update_boot_health', 'target' => 'fixture-host', 'expectations' => identities).ok?).to be(false)
  end

  it 'rejects multiple hosts before running any task' do
    expect_task('nest::update_boot_health').not_be_called

    expect(run_plan('nest::host::update_boot_health', 'target' => ['one', 'two'], 'expectations' => identities).ok?).to be(false)
  end
end
