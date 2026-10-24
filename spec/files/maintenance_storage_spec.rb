# frozen_string_literal: true

require 'json'
require 'open3'
require 'rbconfig'

RSpec.describe 'maintenance-storage' do
  let(:script) { File.expand_path('../../files/kubernetes/maintenance-storage.rb', __dir__) }
  let(:fsid) { '12345678-1234-1234-1234-123456789abc' }
  let(:etcd) do
    { 'mounts' => { 'filesystems' => [{ 'source' => 'fixture/crypt/etcd', 'fstype' => 'zfs' }] },
      'pools' => "fixture\t123\tONLINE\nunrelated\t456\tDEGRADED\n", 'status' => "pool 'fixture' is healthy\n" }
  end
  let(:ceph) do
    { 'fsid' => fsid, 'health' => { 'status' => 'HEALTH_OK', 'checks' => {} }, 'monmap' => { 'num_mons' => 3 },
      'quorum' => [0, 1, 2], 'quorum_names' => ['a', 'b', 'c'],
      'osdmap' => { 'num_osds' => 7, 'num_up_osds' => 7, 'num_in_osds' => 7, 'num_remapped_pgs' => 0 },
      'pgmap' => { 'num_pgs' => 10, 'pgs_by_state' => [{ 'state_name' => 'active+clean', 'count' => 10 }] },
      'mgrmap' => { 'available' => true }, 'fsmap' => { 'up' => 1, 'in' => 1, 'max' => 1 }, 'private' => 'DO_NOT_PRINT' }
  end

  def project(mode, value)
    args = (mode == 'ceph') ? [fsid] : []
    Open3.capture3(RbConfig.ruby, script, mode, *args, stdin_data: JSON.dump(value))
  end

  it 'checks the actual etcd backing pool without requiring unrelated retired pool health' do
    stdout, stderr, status = project('etcd', etcd)
    expect(status).to be_success
    expect(stderr).to be_empty
    expect(JSON.parse(stdout)).to include('dataset' => 'fixture/crypt/etcd', 'pool_guid' => '123')
    expect(stdout).not_to include('unrelated')
  end

  [
    ['missing mount', ->(data) { data['mounts']['filesystems'] = [] }],
    ['unsupported filesystem', ->(data) { data['mounts']['filesystems'][0]['fstype'] = 'ext4' }],
    ['invalid source', ->(data) { data['mounts']['filesystems'][0]['source'] = 'fixture;bad/root' }],
    ['missing backing pool', ->(data) { data['pools'] = "other\t123\tONLINE\n" }],
    ['duplicate pool', ->(data) { data['pools'] += "fixture\t123\tONLINE\n" }],
    ['degraded backing pool', ->(data) { data['pools'] = data['pools'].sub('ONLINE', 'DEGRADED') }],
    ['data errors despite online', ->(data) { data['status'] = 'errors: Permanent errors have been detected' }],
    ['wrong pool status', ->(data) { data['status'] = "pool 'different' is healthy" }],
  ].each do |label, mutate|
    it "refuses #{label}" do
      data = etcd
      mutate.call(data)
      stdout, stderr, status = project('etcd', data)
      expect(status).not_to be_success
      expect(stdout).to be_empty
      expect(stderr).to include('observation refused')
    end
  end

  it 'retains capacity and historical crash warnings separately from live availability' do
    data = ceph
    data['health'] = { 'status' => 'HEALTH_WARN', 'checks' => ['OSD_NEARFULL', 'POOL_NEARFULL', 'RECENT_CRASH', 'RECENT_MGR_MODULE_CRASH'].to_h { |name| [name, { 'severity' => 'HEALTH_WARN' }] } }
    data['pgmap']['pgs_by_state'] = [{ 'state_name' => 'active+clean', 'count' => 8 }, { 'state_name' => 'active+clean+scrubbing+deep', 'count' => 2 }]
    stdout, stderr, status = project('ceph', data)
    expect(status).to be_success
    expect(stderr).to be_empty
    expect(JSON.parse(stdout)).to include('warnings' => data['health']['checks'].keys.sort, 'fsid' => fsid)
    expect(stdout).not_to include('DO_NOT_PRINT', 'private')
  end

  [
    ['wrong cluster', ->(data) { data['fsid'] = 'different' }],
    ['health error', ->(data) { data['health']['status'] = 'HEALTH_ERR' }],
    ['unknown warning', ->(data) { data['health'] = { 'status' => 'HEALTH_WARN', 'checks' => { 'SLOW_OPS' => { 'severity' => 'HEALTH_WARN' } } } }],
    ['missing health checks', ->(data) { data['health'].delete('checks') }],
    ['missing monitor', ->(data) { data['quorum'].pop }],
    ['duplicate quorum', ->(data) { data['quorum'] = [0, 0, 2] }],
    ['duplicate monitor name', ->(data) { data['quorum_names'] = ['a', 'a', 'c'] }],
    ['missing OSD', ->(data) { data['osdmap']['num_up_osds'] = 6 }],
    ['out OSD', ->(data) { data['osdmap']['num_in_osds'] = 6 }],
    ['remapped PG', ->(data) { data['osdmap']['num_remapped_pgs'] = 1 }],
    ['degraded PG', ->(data) { data['pgmap']['pgs_by_state'][0]['state_name'] = 'active+undersized+degraded' }],
    ['missing PG', ->(data) { data['pgmap']['num_pgs'] = 11 }],
    ['duplicate PG summary', ->(data) { data['pgmap']['pgs_by_state'] *= 2 }],
    ['missing manager', ->(data) { data['mgrmap']['available'] = false }],
    ['missing MDS', ->(data) { data['fsmap']['up'] = 0 }],
    ['unknown MDS state', ->(data) { data.delete('fsmap') }],
  ].each do |label, mutate|
    it "refuses #{label} without printing native private fields" do
      data = ceph
      mutate.call(data)
      stdout, stderr, status = project('ceph', data)
      expect(status).not_to be_success
      expect(stdout).to be_empty
      expect(stderr).to include('observation refused')
      expect(stderr).not_to include('DO_NOT_PRINT')
    end
  end
end
