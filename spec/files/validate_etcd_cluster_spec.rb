# frozen_string_literal: true

require 'json'
require 'open3'
require 'rbconfig'
require 'tempfile'

RSpec.describe 'validate-etcd-cluster' do
  let(:repo_root) { File.expand_path('../..', __dir__) }
  let(:script) { File.join(repo_root, 'files/kubernetes/validate-etcd-cluster.rb') }
  let(:names) { ['control1', 'control2', 'control3'] }
  let(:ids) { [11, 22, 33] }
  let(:leader) { 33 }
  let(:members) do
    {
      'members' => names.zip(ids).map do |name, id|
        { 'ID' => id, 'name' => name, 'isLearner' => false }
      end,
    }
  end
  let(:statuses) do
    ids.each_with_index.map do |id, index|
      {
        'Endpoint' => "https://172.22.4.#{index + 7}:2379",
        'Status' => {
          'header' => { 'member_id' => id, 'cluster_id' => 44 },
          'leader' => leader,
          'raftTerm' => 7,
          'raftIndex' => 1100,
          'raftAppliedIndex' => 1000 + index,
        },
      }
    end
  end

  def validate(statuses, members, max_lag: 100, previous: nil)
    Tempfile.create('etcd-status') do |status_file|
      Tempfile.create('etcd-members') do |members_file|
        status_file.write(JSON.dump(statuses))
        status_file.flush
        members_file.write(JSON.dump(members))
        members_file.flush
        previous_args = []
        if previous
          before_status = Tempfile.new('etcd-before-status')
          before_members = Tempfile.new('etcd-before-members')
          before_status.write(JSON.dump(previous.fetch(:statuses)))
          before_status.flush
          before_members.write(JSON.dump(previous.fetch(:members)))
          before_members.flush
          previous_args = ['--json', '--previous-status', before_status.path, '--previous-members', before_members.path]
        end
        return Open3.capture3(
          RbConfig.ruby,
          script,
          *previous_args,
          status_file.path,
          members_file.path,
          max_lag.to_s,
          *names,
        )
      ensure
        before_status&.close!
        before_members&.close!
      end
    end
  end

  it 'accepts the exact healthy voting topology with bounded lag' do
    stdout, stderr, status = validate(statuses, members)

    expect(status).to be_success
    expect(stderr).to be_empty
    expect(stdout).to include('members=control1,control2,control3', 'applied_index_lag=2')
  end

  it 'rejects missing members' do
    _stdout, stderr, status = validate(statuses.drop(1), { 'members' => members.fetch('members').drop(1) })

    expect(status).not_to be_success
    expect(stderr).to include('expected 3 endpoint statuses, got 2')
  end

  it 'rejects learners' do
    learner_members = Marshal.load(Marshal.dump(members))
    learner_members.fetch('members').first['isLearner'] = true
    _stdout, stderr, status = validate(statuses, learner_members)

    expect(status).not_to be_success
    expect(stderr).to include('learners are not allowed')
  end

  it 'rejects inconsistent leaders' do
    inconsistent = Marshal.load(Marshal.dump(statuses))
    inconsistent.first.fetch('Status')['leader'] = 22
    _stdout, stderr, status = validate(inconsistent, members)

    expect(status).not_to be_success
    expect(stderr).to include('expected one nonzero leader')
  end

  it 'rejects excessive applied-index lag' do
    lagging = Marshal.load(Marshal.dump(statuses))
    lagging.first.fetch('Status')['raftAppliedIndex'] = 500
    _stdout, stderr, status = validate(lagging, members, max_lag: 100)

    expect(status).not_to be_success
    expect(stderr).to include('applied-index lag 502 exceeds 100')
  end

  it 'rejects duplicate voting identities even when status covers the same multiset' do
    duplicate_members = Marshal.load(Marshal.dump(members))
    duplicate_status = Marshal.load(Marshal.dump(statuses))
    duplicate_members.fetch('members')[0]['ID'] = 22
    duplicate_status[0].fetch('Status').fetch('header')['member_id'] = 22

    _stdout, stderr, status = validate(duplicate_status, duplicate_members)

    expect(status).not_to be_success
    expect(stderr).to include('duplicate voting member identity')
  end

  [
    ['cluster mismatch', ->(rows) { rows[0]['Status']['header']['cluster_id'] = 55 }],
    ['errors', ->(rows) { rows[0]['Status']['errors'] = ['fault'] }],
    ['negative index', ->(rows) { rows[0]['Status']['raftAppliedIndex'] = -1 }],
    ['float index', ->(rows) { rows[0]['Status']['raftAppliedIndex'] = 1000.0 }],
    ['uncommitted index', ->(rows) { rows[0]['Status']['raftIndex'] = 999 }],
    ['term mismatch', ->(rows) { rows[0]['Status']['raftTerm'] = 8 }],
    ['duplicate endpoint', ->(rows) { rows[0]['Endpoint'] = rows[1]['Endpoint'] }],
  ].each do |label, change|
    it "rejects #{label} rather than treating malformed accounting as health" do
      invalid = Marshal.load(Marshal.dump(statuses))
      change.call(invalid)

      stdout, _stderr, status = validate(invalid, members)

      expect(status).not_to be_success
      expect(stdout).to be_empty
    end
  end

  it 'requires each exact voting member to advance, regardless of row order' do
    advanced = Marshal.load(Marshal.dump(statuses))
    advanced.each { |entry| entry.fetch('Status')['raftAppliedIndex'] += 10 }
    stdout, stderr, status = validate(advanced.reverse, members, previous: { statuses: statuses, members: members })

    expect(status).to be_success
    expect(stderr).to be_empty
    expect(JSON.parse(stdout)).to include('kind' => 'nest_etcd_quorum_observation', 'advancing' => true,
                                        'progress' => { '11' => 10, '22' => 10, '33' => 10 }, 'acceptance_recorded' => false)
  end

  it 'does not infer progress from a synchronized but unchanged snapshot' do
    stdout, stderr, status = validate(statuses, members, previous: { statuses: statuses, members: members })

    expect(status).not_to be_success
    expect(stdout).to be_empty
    expect(stderr).to include('did not advance')
  end

  ['cluster_id', 'raftTerm', 'leader'].each do |field|
    it "refuses a changed #{field} across otherwise healthy samples" do
      advanced = Marshal.load(Marshal.dump(statuses))
      advanced.each do |entry|
        entry.fetch('Status')['raftAppliedIndex'] += 10
        if field == 'cluster_id'
          entry.fetch('Status').fetch('header')[field] = 55
        else
          entry.fetch('Status')[field] = (field == 'leader') ? 22 : 8
        end
      end
      stdout, stderr, status = validate(advanced, members, previous: { statuses: statuses, members: members })

      expect(status).not_to be_success
      expect(stdout).to be_empty
      expect(stderr).to include('changed during progress observation')
    end
  end
end
