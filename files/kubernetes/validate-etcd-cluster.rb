#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'optparse'

# Preserve the positional single-sample interface used by existing maintenance.
# Progress is an explicit two-sample contract, never inferred from small lag.
def uint(value, positive: true)
  raise 'invalid unsigned etcd identity or index' unless value.is_a?(Integer) && value >= (positive ? 1 : 0) && value < 2**64

  value
end

def sample(status_path, members_path, max_lag, expected_names)
  statuses = JSON.parse(File.read(status_path))
  members = JSON.parse(File.read(members_path)).fetch('members')
  raise 'invalid endpoint or member inventory' unless statuses.is_a?(Array) && members.is_a?(Array)
  raise "expected #{expected_names.length} endpoint statuses, got #{statuses.length}" unless statuses.length == expected_names.length
  raise "expected #{expected_names.length} members, got #{members.length}" unless members.length == expected_names.length

  actual_names = members.map { |member| member.fetch('name') }
  raise 'member names differ from expected topology' unless actual_names.sort == expected_names.sort
  raise 'etcd learners are not allowed in the rollout gate' if members.any? { |member| member['isLearner'] }

  member_ids = members.map { |member| uint(member.fetch('ID')) }
  raise 'duplicate voting member identity' unless member_ids.uniq.length == member_ids.length

  status_ids = statuses.map { |entry| uint(entry.fetch('Status').fetch('header').fetch('member_id')) }
  raise 'endpoint status does not cover every configured member exactly once' unless status_ids.sort == member_ids.sort

  endpoints = statuses.map { |entry| entry.fetch('Endpoint') }
  raise 'invalid or duplicate endpoint identity' unless endpoints.all? { |endpoint| endpoint.is_a?(String) && endpoint.match?(%r{\Ahttps://[^\s/]+:2379\z}) } && endpoints.uniq == endpoints

  rows = statuses.map { |entry| entry.fetch('Status') }
  raise 'endpoint reports errors' unless rows.all? { |row| row.fetch('errors', []) == [] }

  clusters = rows.map { |row| uint(row.fetch('header').fetch('cluster_id')) }.uniq
  raise 'endpoint cluster identities disagree' unless clusters.length == 1

  leaders = rows.map { |row| uint(row.fetch('leader')) }.uniq
  raise "expected one nonzero leader, got #{leaders.inspect}" unless leaders.length == 1 && member_ids.include?(leaders.first)

  terms = rows.map { |row| uint(row.fetch('raftTerm')) }.uniq
  raise 'endpoint raft terms disagree' unless terms.length == 1

  applied = rows.map { |row| uint(row.fetch('raftAppliedIndex'), positive: false) }
  raise 'applied index exceeds committed index' unless rows.each_with_index.all? { |row, index| uint(row.fetch('raftIndex'), positive: false) >= applied[index] }

  lag = applied.max - applied.min
  raise "applied-index lag #{lag} exceeds #{max_lag}" if lag > max_lag

  {
    'members' => members.map { |member| [member.fetch('name'), member.fetch('ID')] }.sort.to_h,
    'cluster_id' => clusters.first, 'leader' => leaders.first, 'raft_term' => terms.first,
    'applied_index_lag' => lag,
    'applied_indexes' => status_ids.zip(applied).sort.to_h,
    'endpoints' => status_ids.zip(endpoints).sort.to_h,
  }
end

options = {}
options_parser = OptionParser.new do |parser|
  parser.on('--json') { options[:json] = true }
  parser.on('--previous-status FILE') { |value| options[:status] = value }
  parser.on('--previous-members FILE') { |value| options[:members] = value }
end
options_parser.parse!
status_path, members_path, max_lag, *expected_names = ARGV
raise 'usage: validate-etcd-cluster [--json] [--previous-status FILE --previous-members FILE] STATUS MEMBERS MAX_LAG MEMBER...' if expected_names.empty?
raise 'invalid expected member names' unless expected_names.uniq == expected_names && expected_names.all? { |name| name.match?(%r{\A[a-z0-9][a-z0-9.-]{0,127}\z}) }

lag_limit = Integer(max_lag, 10)
raise 'invalid maximum lag' unless lag_limit.between?(0, 1000)
raise 'both previous sample files are required' unless options.key?(:status) == options.key?(:members)

observed = sample(status_path, members_path, lag_limit, expected_names)
progress = nil
if options[:status]
  previous = sample(options[:status], options[:members], lag_limit, expected_names)
  ['members', 'cluster_id', 'leader', 'raft_term', 'endpoints'].each do |key|
    raise "etcd #{key} changed during progress observation" unless previous.fetch(key) == observed.fetch(key)
  end
  progress = observed.fetch('applied_indexes').map { |id, index|
    advanced = index - previous.fetch('applied_indexes').fetch(id)
    raise 'member applied index did not advance' unless advanced.positive?

    [id.to_s, advanced]
  }.to_h
end
if options[:json]
  report = {
    'schema' => 1, 'kind' => 'nest_etcd_quorum_observation', 'result' => 'pass',
    'members' => observed.fetch('members').transform_values(&:to_s),
    'cluster_id' => observed.fetch('cluster_id').to_s, 'leader' => observed.fetch('leader').to_s,
    'raft_term' => observed.fetch('raft_term'), 'applied_index_lag' => observed.fetch('applied_index_lag'),
    'progress' => progress, 'advancing' => !progress.nil?, 'acceptance_recorded' => false,
  }
  puts JSON.generate(report)
else
  puts "members=#{expected_names.sort.join(',')} leader=#{observed.fetch('leader')} applied_index_lag=#{observed.fetch('applied_index_lag')}"
end
