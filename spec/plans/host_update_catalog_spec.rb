require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'nest::host::update_catalog' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-catalog-spec-') }

  def modulepath
    [plan_modulepath, File.expand_path('../fixtures/modules', __dir__)]
  end

  around :each do |example|
    File.symlink(File.expand_path('../..', __dir__), File.join(plan_modulepath, 'nest'))
    example.run
  ensure
    FileUtils.remove_entry(plan_modulepath)
  end

  def apply(first, second = nil)
    exits = second.nil? ? [first] : [first, second]
    seen = []
    expect_script('nest/run_puppet.sh').be_called_times(exits.length).return do |targets:, params:, **_others|
      expect(targets.map(&:name)).to eq(['fixture-host'])
      expect(params[:run_as]).to eq('root')
      env = params[:env_vars]
      expect(env['PUPPET_PRESERVE_DETAILED_EXIT']).to eq('true')
      expect(env['PUPPET_EXTRA_ARGS']).to include('--environment', 'main', '--no-noop', '--no-use_cached_catalog', '--no-usecacheonfailure', '--tags', '--skip_tags')
      seen << exits.shift
      Bolt::ResultSet.new(targets.map do |target|
        Bolt::Result.for_command(target, { 'exit_code' => seen.last, 'stdout' => 'private catalog log', 'stderr' => 'private error' }, 'command', 'fixture', [])
      end)
    end
    result = run_plan('nest::host::update_catalog', 'target' => 'fixture-host')
    expect(result.ok?).to be(true)
    expect(result.value.to_s).not_to include('private catalog log', 'private error')
    result.value
  end

  [0, 2].each do |first|
    it "accepts native first exit #{first} only with an unchanged repeat" do
      expect(apply(first, 0)).to include('main_exit' => first, 'repeat_exit' => 0, 'repeat_attempted' => true,
                                        'result' => 'pass', 'converged' => true, 'requested_environment' => 'main',
                                        'served_source_verified' => false, 'acceptance_recorded' => false)
    end
  end

  [1, 4, 6, 37].each do |first|
    it "retains failed first exit #{first} without repeating the apply" do
      expect(apply(first)).to include('main_exit' => first, 'repeat_exit' => nil, 'repeat_attempted' => false,
                                     'result' => 'fail', 'converged' => false)
    end
  end

  [1, 2, 4, 6, 37].each do |second|
    it "does not call repeat exit #{second} converged or retry it" do
      expect(apply(2, second)).to include('main_exit' => 2, 'repeat_exit' => second,
                                        'result' => 'fail', 'converged' => false)
    end
  end

  it 'does not turn a transport error into an unchanged apply or repeat' do
    expect_script('nest/run_puppet.sh').error_with('kind' => 'fixture/transport', 'msg' => 'Unavailable')
    result = run_plan('nest::host::update_catalog', 'target' => 'fixture-host')
    expect(result.ok?).to be(true)
    expect(result.value).to include('main_exit' => nil, 'repeat_attempted' => false, 'result' => 'fail')
  end

  it 'rejects multiple targets before executing any apply' do
    expect_script('nest/run_puppet.sh').not_be_called
    expect(run_plan('nest::host::update_catalog', 'target' => ['one', 'two']).ok?).to be(false)
  end

  it 'routes explicit invocation expectations to the mutating bound task exactly once' do
    expected = { 'hostname' => 'fixture', 'certname' => 'fixture.nest',
                 'boot_id' => '11111111-1111-4111-8111-111111111111', 'configuration_version' => 'a' * 40 }
    expect_script('nest/run_puppet.sh').not_be_called
    expect_task('nest::update_catalog_apply').be_called_times(1).return do |targets:, params:, **_others|
      expect(targets.map(&:name)).to eq(['fixture-host'])
      expect(params).to include('expectations' => expected, '_run_as' => 'root')
      Bolt::ResultSet.new(targets.map do |target|
        Bolt::Result.new(target, value: { 'schema' => 1, 'kind' => 'nest_update_catalog_bound', 'result' => 'fail', 'acceptance_recorded' => false })
      end)
    end
    result = run_plan('nest::host::update_catalog', 'target' => 'fixture-host', 'expectations' => expected)
    expect(result.ok?).to be(true)
    expect(result.value).to include('kind' => 'nest_update_catalog_bound', 'result' => 'fail', 'acceptance_recorded' => false)
  end
end
