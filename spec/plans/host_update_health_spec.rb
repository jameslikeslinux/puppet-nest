require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'nest::host::update_health' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-health-spec-') }
  let(:boot_id) { '11111111-2222-3333-4444-555555555555' }
  let(:identities) { { 'hostname' => 'fixture-host', 'kernel' => '6.18.57' } }
  let(:boot) do
    { 'schema' => 1, 'kind' => 'nest_update_boot_health', 'hostname' => 'fixture-host',
      'boot_id' => boot_id, 'result' => 'pass', 'acceptance_recorded' => false }
  end
  let(:managers) do
    { 'schema' => 1, 'kind' => 'nest_update_manager_health', 'hostname' => 'fixture-host',
      'boot_id' => boot_id, 'result' => 'pass', 'acceptance_recorded' => false }
  end

  let(:endpoints) { [{ 'hostname' => 'service.example', 'addresses' => ['192.0.2.1'], 'path' => '/readyz', 'status' => 200 }] }
  let(:network) do
    { 'schema' => 1, 'kind' => 'nest_update_network_health', 'hostname' => 'fixture-host',
      'boot_id' => boot_id, 'result' => 'pass', 'acceptance_recorded' => false }
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

  def observe(before = boot, manager = managers, after = before, client = nil)
    calls = []
    expect_plan('nest::host::update_boot_health').be_called_times(2).return do |params:, **_options|
      expect(params['target'].name).to eq('fixture-host')
      expect(params['expectations']).to eq(identities)
      calls << 'boot'
      Bolt::PlanResult.new((calls.count('boot') == 1) ? before : after, 'success')
    end
    expect_plan('nest::host::update_manager_health').return do |params:, **_options|
      expect(params['target'].name).to eq('fixture-host')
      calls << 'manager'
      Bolt::PlanResult.new(manager, 'success')
    end
    if client
      expect_plan('nest::host::update_network_health').return do |params:, **_options|
        expect(params['target'].name).to eq('fixture-host')
        expect(params['endpoints']).to eq(endpoints)
        calls << 'network'
        Bolt::PlanResult.new(client, 'success')
      end
    else
      expect_plan('nest::host::update_network_health').not_be_called
    end
    result = run_plan('nest::host::update_health', 'target' => 'fixture-host', 'expectations' => identities,
                                                'endpoints' => client ? endpoints : [])
    expect(result.ok?).to be(true)
    expect(calls).to eq(client ? ['boot', 'manager', 'network', 'boot'] : ['boot', 'manager', 'boot'])
    result.value
  end

  it 'brackets actual manager acquisition with matching boot observations without accepting' do
    value = observe

    expect(value).to include('schema' => 1, 'kind' => 'nest_update_health', 'result' => 'pass',
                            'observations_bound' => true, 'acceptance_recorded' => false)
    expect(value['boot_before']).to eq(boot)
    expect(value['managers']).to eq(managers)
    expect(value['boot_after']).to eq(boot)
    expect(value).to include('network' => nil, 'network_requested' => false)
  end

  it 'binds requested client paths inside the same boot bracket' do
    expect(observe(boot, managers, boot, network)).to include('result' => 'pass', 'observations_bound' => true,
                                                          'network' => network, 'network_requested' => true)
  end

  it 'retains failed or unavailable network observations without accepting' do
    failed = network.merge('result' => 'fail', 'endpoints' => [{ 'availability' => 'unavailable' }])
    expect(observe(boot, managers, boot, failed)).to include('result' => 'fail', 'observations_bound' => true,
                                                         'network' => failed, 'acceptance_recorded' => false)
  end

  [
    ['boot_id', 'aaaaaaaa-2222-3333-4444-555555555555'],
    ['hostname', 'another-host'],
    ['schema', 2],
    ['kind', 'another_kind'],
    ['acceptance_recorded', true],
  ].each do |key, value|
    it "refuses network #{key} substitution" do
      expect(observe(boot, managers, boot, network.merge(key => value))).to include('result' => 'fail', 'observations_bound' => false)
    end
  end

  it 'retains unavailable manager inventories and explained failures without making them healthy' do
    failed = managers.merge('result' => 'fail', 'system_failures' => { 'failures' => ['historic.service'] },
                            'user_managers' => { 'availability' => 'unavailable' })
    value = observe(boot, failed)

    expect(value).to include('result' => 'fail', 'observations_bound' => true, 'acceptance_recorded' => false)
    expect(value['managers']).to eq(failed)
  end

  it 'retains failed boot checks even when the manager is healthy' do
    value = observe(boot.merge('result' => 'fail'))

    expect(value).to include('result' => 'fail', 'observations_bound' => true)
  end

  [
    ['boot_id', 'aaaaaaaa-2222-3333-4444-555555555555'],
    ['hostname', 'another-host'],
    ['schema', 2],
    ['kind', 'another_kind'],
    ['acceptance_recorded', true],
  ].each do |key, value|
    it "refuses manager #{key} substitution" do
      expect(observe(boot, managers.merge(key => value))).to include('result' => 'fail', 'observations_bound' => false)
    end
  end

  [
    ['boot_id', 'aaaaaaaa-2222-3333-4444-555555555555'],
    ['kernel', 'changed-kernel'],
    ['checks', { 'mounts' => { 'result' => 'fail' } }],
  ].each do |key, value|
    it "refuses a changed final boot #{key} observation" do
      expect(observe(boot, managers, boot.merge(key => value))).to include('result' => 'fail', 'observations_bound' => false)
    end
  end

  [
    ['hostname', 'another-host'],
    ['boot_id', 'not-a-boot-id'],
    ['schema', 2],
    ['kind', 'another_kind'],
    ['acceptance_recorded', true],
  ].each do |key, value|
    it "refuses an invalid initial boot #{key}" do
      expect(observe(boot.merge(key => value))).to include('result' => 'fail', 'observations_bound' => false)
    end
  end

  it 'fails on observation task or transport error instead of manufacturing an empty inventory' do
    expect_plan('nest::host::update_boot_health').error_with('kind' => 'nest/unavailable', 'msg' => 'Unavailable')
    expect_plan('nest::host::update_manager_health').not_be_called

    expect(run_plan('nest::host::update_health', 'target' => 'fixture-host', 'expectations' => identities).ok?).to be(false)
  end

  it 'rejects multiple targets before any observation' do
    expect_plan('nest::host::update_boot_health').not_be_called
    expect_plan('nest::host::update_manager_health').not_be_called

    expect(run_plan('nest::host::update_health', 'target' => ['one', 'two'], 'expectations' => identities).ok?).to be(false)
  end
end
