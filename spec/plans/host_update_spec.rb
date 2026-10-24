require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'nest::host::update' do
  include BoltSpec::Plans

  let(:targets) { ['update-good', 'update-failed'] }
  let(:plan_modulepath) { Dir.mktmpdir('nest-plan-spec-') }

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
    # These tests use Bolt's mock executor, never real host commands/reboots.
    allow_plan('nest::host::reboot')
    allow_plan('nest::puppet::run')
  end

  it 'stops after failed preparation without a legacy resume or reboot' do
    expect_command('nest reset').with_targets(targets).return do |targets:, command:, **_options|
      Bolt::ResultSet.new(targets.map do |target|
        value = { 'stdout' => '', 'stderr' => '', 'exit_code' => (target.name == 'update-failed') ? 1 : 0 }
        Bolt::Result.for_command(target, value, 'command', command, [])
      end)
    end
    expect_plan('nest::host::reboot').not_be_called
    expect_plan('nest::puppet::run').not_be_called

    result = run_plan('nest::host::update', 'targets' => targets, 'reboot' => true)

    expect(result.ok?).to be(false)
  end

  it 'does not reboot by default after successful preparation' do
    expect_command('nest reset').with_targets(targets)
    expect_plan('nest::host::reboot').not_be_called

    expect(run_plan('nest::host::update', 'targets' => targets).ok?).to be(true)
  end

  it 'reboots only after all requested preparations succeed' do
    expect_command('nest update').with_targets(targets)
    expect_plan('nest::host::reboot').with_params('targets' => targets)
    expect_plan('nest::puppet::run').with_params('targets' => targets)

    expect(run_plan('nest::host::update', 'targets' => targets, 'reset' => false, 'reboot' => true).ok?).to be(true)
  end

  it 'resolves inventory names and invokes only the supervisor wave planner in plan mode' do
    policy = { 'schema' => 1, 'kind' => 'nest_update_wave_policy' }
    planned = { 'schema' => 1, 'kind' => 'nest_update_wave_plan', 'execution_authorized' => false, 'reboot_eligible' => [] }
    expect_task('nest::update_wave_plan').with_targets('localhost').with_params('policy' => policy, 'targets' => targets).always_return(planned)
    expect_command('nest reset').not_be_called
    expect_command('nest update').not_be_called
    expect_plan('nest::host::reboot').not_be_called
    expect_plan('nest::puppet::run').not_be_called

    result = run_plan('nest::host::update', 'targets' => targets, 'mode' => 'plan', 'policy' => policy)

    expect(result.ok?).to be(true)
    expect(result.value).to eq(planned)
  end

  [
    { 'mode' => 'plan' },
    { 'mode' => 'plan', 'policy' => {}, 'reboot' => true },
    { 'mode' => 'plan', 'policy' => {}, 'reset' => false },
    { 'policy' => {} },
  ].each do |options|
    it "refuses incompatible wave options #{options} without any host action" do
      expect_command('nest reset').not_be_called
      expect_command('nest update').not_be_called
      expect_task('nest::update_wave_plan').not_be_called
      expect_plan('nest::host::reboot').not_be_called
      expect_plan('nest::puppet::run').not_be_called

      expect(run_plan('nest::host::update', options.merge('targets' => targets)).ok?).to be(false)
    end
  end

  it 'does not fall through to execution when policy validation fails' do
    expect_task('nest::update_wave_plan').with_targets('localhost').error_with('kind' => 'nest/update-wave-policy', 'msg' => 'Invalid policy')
    expect_command('nest reset').not_be_called
    expect_plan('nest::host::reboot').not_be_called

    expect(run_plan('nest::host::update', 'targets' => targets, 'mode' => 'plan', 'policy' => {}).ok?).to be(false)
  end
end
