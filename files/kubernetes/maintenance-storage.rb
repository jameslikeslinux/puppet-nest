#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'

# Bounded native projections only. No health mutations or raw private payloads.
def require_observation(condition)
  raise ArgumentError unless condition
end

def positive(value)
  value.is_a?(Integer) && value.positive?
end

begin
  mode = ARGV.shift
  raw = $stdin.read(1_048_577)
  require_observation(raw.bytesize <= 1_048_576)
  case mode
  when 'etcd'
    require_observation(ARGV.empty?)
    input = JSON.parse(raw)
    mounts = input.fetch('mounts').fetch('filesystems')
    require_observation(mounts.is_a?(Array) && mounts.length == 1)
    mount = mounts[0]
    dataset = mount.fetch('source')
    require_observation(mount['fstype'] == 'zfs' && dataset.is_a?(String) && dataset.match?(%r{\A[A-Za-z][A-Za-z0-9_.-]*(?:/[A-Za-z0-9_.:-]+)+\z}))
    pool = dataset.split('/')[0]
    rows = input.fetch('pools').lines.map { |line| line.chomp.split("\t", -1) }
    require_observation(rows.length.between?(1, 128) && rows.all? { |row| row.length == 3 } && rows.map(&:first).uniq.length == rows.length)
    selected = rows.select { |row| row[0] == pool }
    require_observation(selected.length == 1 && selected[0][1].match?(%r{\A[1-9][0-9]{0,19}\z}) && selected[0][2] == 'ONLINE')
    # Unrelated retired pools are not made an availability dependency. Inspect
    # errors for the actual backing pool separately, not aggregate HEALTH alone.
    require_observation(input.fetch('status').strip == "pool '#{pool}' is healthy")
    puts JSON.generate('schema' => 1, 'kind' => 'nest_etcd_storage', 'dataset' => dataset, 'pool_guid' => selected[0][1])
  when 'ceph'
    require_observation(ARGV.length == 1 && ARGV[0].match?(%r{\A[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\z}))
    input = JSON.parse(raw)
    require_observation(input.fetch('fsid') == ARGV[0])
    health = input.fetch('health')
    require_observation(['HEALTH_OK', 'HEALTH_WARN'].include?(health['status']) && health['checks'].is_a?(Hash))
    # Capacity warnings and retained crash records are reported, not cleared or
    # mislabelled as current availability failure. Full/degraded/unknown checks
    # still refuse; this is not capacity admission for copying a new release.
    warnings = ['OSD_NEARFULL', 'POOL_NEARFULL', 'RECENT_CRASH', 'RECENT_MGR_MODULE_CRASH']
    require_observation((health['checks'].keys - warnings).empty?)
    require_observation(health['checks'].all? { |_name, check| check.is_a?(Hash) && check['severity'] == 'HEALTH_WARN' })
    require_observation(health['status'] != 'HEALTH_OK' || health['checks'].empty?)
    mons = input.fetch('monmap').fetch('num_mons')
    quorum = input.fetch('quorum')
    names = input.fetch('quorum_names')
    require_observation(positive(mons) && mons.odd? && mons >= 3 && quorum.is_a?(Array) && quorum.length == mons && quorum.uniq == quorum &&
                        quorum.all? { |id| id.is_a?(Integer) && id >= 0 } && names.is_a?(Array) && names.length == mons && names.uniq == names &&
                        names.all? { |name| name.is_a?(String) && name.match?(%r{\A[a-zA-Z0-9_.-]{1,128}\z}) })
    osds = input.fetch('osdmap')
    require_observation(positive(osds['num_osds']) && osds['num_up_osds'] == osds['num_osds'] && osds['num_in_osds'] == osds['num_osds'] && osds['num_remapped_pgs'] == 0)
    pgs = input.fetch('pgmap')
    states = pgs.fetch('pgs_by_state')
    require_observation(positive(pgs['num_pgs']) && states.is_a?(Array) && !states.empty?)
    require_observation(states.all? { |row| row.is_a?(Hash) && positive(row['count']) && ['active+clean', 'active+clean+scrubbing', 'active+clean+scrubbing+deep'].include?(row['state_name']) })
    require_observation(states.sum { |row| row['count'] } == pgs['num_pgs'] && states.map { |row| row['state_name'] }.uniq.length == states.length)
    require_observation(input.fetch('mgrmap')['available'] == true)
    fs = input.fetch('fsmap')
    require_observation(positive(fs['up']) && fs['up'] == fs['in'] && fs['up'] == fs['max'])
    puts JSON.generate('schema' => 1, 'kind' => 'nest_ceph_availability', 'fsid' => input['fsid'],
                       'quorum_names' => names.sort, 'osds' => osds['num_osds'], 'pgs' => pgs['num_pgs'], 'warnings' => health['checks'].keys.sort)
  else
    raise ArgumentError
  end
rescue StandardError
  warn 'Maintenance storage observation refused: missing, unhealthy or unsupported native evidence'
  exit 1
end
