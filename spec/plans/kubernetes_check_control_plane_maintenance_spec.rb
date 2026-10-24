require 'spec_helper'
require 'bolt_spec/plans'
require 'tmpdir'

RSpec.describe 'nest::kubernetes::check_control_plane_maintenance' do
  include BoltSpec::Plans

  let(:plan_modulepath) { Dir.mktmpdir('nest-maintenance-spec-') }
  let(:params) do
    { 'target' => 'control3', 'survivor' => 'control1', 'client' => 'owl',
      'advertisers' => { 'control1' => '172.22.4.7', 'control2' => '172.22.4.8' },
      'physical_domains' => ['control1', 'control2', 'control3', 'owl', 'eyrie-storage'].to_h { |name| [name, ["fixture-#{name}"]] },
      'ceph_fsid' => '12345678-1234-1234-1234-123456789abc' }
  end
  let(:storage) { { 'schema' => 1, 'kind' => 'nest_etcd_storage', 'dataset' => 'fixture/etcd', 'pool_guid' => '123' } }
  let(:ceph) { { 'schema' => 1, 'kind' => 'nest_ceph_availability', 'fsid' => params['ceph_fsid'], 'warnings' => ['RECENT_CRASH'] } }

  def modulepath
    [plan_modulepath, File.expand_path('../fixtures/modules', __dir__)]
  end

  around :each do |example|
    File.symlink(File.expand_path('../..', __dir__), File.join(plan_modulepath, 'nest'))
    example.run
  ensure
    FileUtils.remove_entry(plan_modulepath)
  end

  def observations(change = nil)
    counts = Hash.new(0)
    allow_any_command.expect_call.be_called_times(8).return do |targets:, command:, **_options|
      expect(command).not_to include('reboot', 'defrag', 'scrub start', 'systemctl', 'rsync ')
      if command.include?('findmnt --json')
        name = targets.first.name
        expect(name).to match(%r{\Acontrol[123]\z})
        expect(command).to include('timeout 5s zpool status -x', 'trap ', 'LC_ALL=C')
        counts[name] += 1
        result = (change == :storage && counts[name] == 2) ? storage.merge('pool_guid' => '456') : storage
      else
        expect(targets.map(&:name)).to eq(['owl'])
        expect(command).to include('timeout --signal=TERM --kill-after=2s 20s', '--request-timeout=10s', 'ceph status --format json')
        counts[:ceph] += 1
        result = (change == :ceph && counts[:ceph] == 2) ? ceph.merge('fsid' => 'changed') : ceph
      end
      Bolt::ResultSet.new(targets.map { |target| Bolt::Result.for_command(target, { 'stdout' => JSON.dump(result), 'stderr' => '', 'exit_code' => 0 }, 'command', command, []) })
    end
  end

  it 'composes all voters backing storage, Ceph availability and actual client survivor observations without authority' do
    observations
    expected = params.reject { |name, _value| ['ceph_fsid', 'physical_domains'].include?(name) }.merge('vip' => '172.21.255.255', 'expected_servers' => nil)
    expect_plan('nest::kubernetes::check_api_survivor').with_params(expected).always_return('kind' => 'nest_api_survivor_check')

    result = run_plan('nest::kubernetes::check_control_plane_maintenance', params)

    expect(result.ok?).to be(true)
    expect(result.value).to include('ceph' => ceph, 'etcd_storage' => [storage, storage, storage], 'physical_independence' => 'declared_policy_only',
                                    'reboot_eligible' => [], 'acceptance_recorded' => false)
  end

  [:storage, :ceph].each do |change|
    it "refuses #{change} identity turnover" do
      observations(change)
      expect_plan('nest::kubernetes::check_api_survivor').always_return('kind' => 'nest_api_survivor_check')
      expect(run_plan('nest::kubernetes::check_control_plane_maintenance', params).ok?).to be(false)
    end
  end

  it 'stops before API sampling on native storage failure without retry or mutation' do
    allow_any_command.expect_call.be_called_times(1).return do |targets:, command:, **_options|
      Bolt::ResultSet.new(targets.map { |target| Bolt::Result.for_command(target, { 'stdout' => '', 'stderr' => 'unhealthy', 'exit_code' => 1 }, 'command', command, []) })
    end
    expect_plan('nest::kubernetes::check_api_survivor').not_be_called
    expect(run_plan('nest::kubernetes::check_control_plane_maintenance', params).ok?).to be(false)
  end

  it 'labels explicitly omitted API-only Ceph sampling without inventing storage acceptance' do
    allow_any_command.expect_call.be_called_times(6).return do |targets:, command:, **_options|
      expect(command).to include('findmnt --json')
      Bolt::ResultSet.new(targets.map { |target| Bolt::Result.for_command(target, { 'stdout' => JSON.dump(storage), 'stderr' => '', 'exit_code' => 0 }, 'command', command, []) })
    end
    expect_plan('nest::kubernetes::check_api_survivor').always_return('kind' => 'nest_api_survivor_check')
    result = run_plan('nest::kubernetes::check_control_plane_maintenance', params.merge('ceph_fsid' => nil))
    expect(result.ok?).to be(true)
    expect(result.value['ceph']).to eq('result' => 'not_requested_api_only')
    expect(result.value['reboot_eligible']).to eq([])
  end

  ['control1', 'control2', 'owl', 'eyrie-storage'].each do |protected|
    it "refuses shared power/USB domain with #{protected} before any host command" do
      data = params
      data['physical_domains']['control3'] = data['physical_domains'][protected]
      allow_any_command.not_be_called
      expect(run_plan('nest::kubernetes::check_control_plane_maintenance', data).ok?).to be(false)
    end
  end

  [
    ->(data) { data['physical_domains'].delete('control2') },
    ->(data) { data['physical_domains']['control3'] = [] },
    ->(data) { data['physical_domains']['control3'] = ['bad;domain'] },
    ->(data) { data['ceph_fsid'] = 'not-an-identity' },
    ->(data) { data['survivor'] = 'control3' },
    ->(data) { data['client'] = 'control2' },
    ->(data) { data['target'] = ['control2', 'control3'] },
    ->(data) { data['advertisers'].delete('control1') },
  ].each_with_index do |mutate, index|
    it "refuses invalid or missing required scope #{index}" do
      data = params
      mutate.call(data)
      allow_any_command.not_be_called
      expect(run_plan('nest::kubernetes::check_control_plane_maintenance', data).ok?).to be(false)
    end
  end
end
