#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'yaml'
require 'ipaddr'

# Only public path/runtime identities leave this projector, never Pod contents.
def refuse(message)
  warn "API survivor observation refused: #{message}"
  exit 1
end

def ipv4(value)
  value.is_a?(String) && IPAddr.new(value).ipv4? && IPAddr.new(value).to_s == value
rescue IPAddr::InvalidAddressError
  false
end

def hops(route)
  refuse('unsupported route type or flags') unless route.fetch('type', 'unicast') == 'unicast' && route.fetch('flags', []) == []
  rows = route.key?('nexthops') ? route['nexthops'] : [route]
  refuse('missing kernel next hops') unless rows.is_a?(Array) && rows.length.between?(1, 7)
  result = rows.map do |row|
    refuse('unusable kernel next hop') unless row.is_a?(Hash) && ipv4(row['gateway']) && row['dev'].is_a?(String) &&
                                              row['dev'].match?(%r{\A[a-zA-Z0-9_.:-]{1,15}\z}) && row.fetch('flags', []) == []
    { 'gateway' => row['gateway'], 'dev' => row['dev'] }
  end
  refuse('duplicate kernel next hop') unless result.uniq == result
  result.sort_by { |row| [row['gateway'], row['dev']] }
end

def vip_config(pod, survivor, address, ip)
  refuse('expected one VIP Pod') unless pod.is_a?(Hash) && pod['apiVersion'] == 'v1' && pod['kind'] == 'Pod'
  spec = pod.fetch('spec')
  refuse('VIP must use host networking') unless spec['hostNetwork'] == true
  containers = spec.fetch('containers')
  refuse('expected one VIP container') unless containers.is_a?(Array) && containers.length == 1 && containers[0]['name'] == 'kube-vip'
  container = containers[0]
  env = container.fetch('env')
  refuse('duplicate VIP environment names') unless env.is_a?(Array) && env.map { |item| item.fetch('name') }.uniq.length == env.length
  values = env.to_h { |item| [item.fetch('name'), item['value']] }
  required = {
    'cp_enable' => 'true', 'bgp_enable' => 'true', 'address' => address, 'port' => '6443', 'bgp_routerid' => ip,
    'control_plane_health_check_address' => "https://#{survivor}:6443/readyz",
    'control_plane_health_check_ca_path' => '/etc/kubernetes/pki/ca.crt',
  }
  refuse('VIP or strict local readiness policy differs') unless required.all? { |name, value| values[name] == value }
  ca = '/etc/kubernetes/pki/ca.crt'
  mounts = container.fetch('volumeMounts').select { |mount| mount['mountPath'] == ca }
  refuse('missing read-only health CA mount') unless mounts.length == 1 && mounts[0]['readOnly'] == true
  volumes = spec.fetch('volumes').select { |volume| volume['name'] == mounts[0]['name'] }
  refuse('unexpected health CA source') unless volumes.length == 1 && volumes[0]['hostPath'] == { 'path' => ca, 'type' => 'File' }
  image = container.fetch('image')
  refuse('invalid VIP image identity') unless image.is_a?(String) && image.match?(%r{\A[a-zA-Z0-9./:@_-]{1,256}\z})
  required.merge('image' => image)
end

begin
  mode = ARGV.shift
  input = JSON.parse($stdin.read)
  case mode
  when 'route'
    refuse('expected VIP, survivor address and allowed next hops') unless ARGV.length == 3
    vip, survivor_ip, allowed_csv = ARGV
    allowed = allowed_csv.split(',', -1)
    refuse('invalid route policy') unless ipv4(vip) && ipv4(survivor_ip) && allowed.length.between?(1, 7) &&
                                          allowed.uniq == allowed && allowed.all? { |ip| ipv4(ip) } && allowed.include?(survivor_ip)
    routes = input.fetch('routes')
    lookup = input.fetch('lookup')
    refuse('expected one exact kernel route and lookup') unless routes.is_a?(Array) && routes.length == 1 && lookup.is_a?(Array) && lookup.length == 1
    route = routes[0]
    selected = lookup[0]
    refuse('missing exact BIRD kernel route') unless [vip, "#{vip}/32"].include?(route['dst']) && route['protocol'] == 'bird'
    refuse('wrong route lookup destination or table') unless selected['dst'] == vip && [100, '100', 'bird'].include?(selected['table'])
    next_hops = hops(route)
    refuse('survivor absent or unexpected kernel next hop') unless next_hops.any? { |row| row['gateway'] == survivor_ip } && next_hops.all? { |row| allowed.include?(row['gateway']) }
    selected_hops = hops(selected)
    refuse('lookup is not through the observed kernel route') unless selected_hops.length == 1 && next_hops.include?(selected_hops[0])
    # ECMP can legitimately choose a different member between samples. Preserve
    # the stable usable set, not incidental cache/UID/flow-selected details.
    puts JSON.generate('schema' => 1, 'kind' => 'nest_api_survivor_route', 'vip' => vip, 'table' => 100,
                       'next_hops' => next_hops, 'survivor_ip' => survivor_ip, 'acceptance_recorded' => false)
  when 'vip'
    refuse('expected survivor, VIP, survivor address and manifest') unless ARGV.length == 4
    survivor, vip, ip, path = ARGV
    refuse('invalid survivor identity') unless survivor.match?(%r{\A[a-z0-9][a-z0-9.-]{0,127}\z}) && ipv4(vip) && ipv4(ip)
    desired = YAML.safe_load_file(path, permitted_classes: [], permitted_symbols: [], aliases: false)
    refuse('static and runtime VIP policy differ') unless vip_config(desired, survivor, vip, ip) == vip_config(input, survivor, vip, ip)
    metadata = input.fetch('metadata')
    refuse('unexpected or terminating mirror Pod') unless metadata['name'] == "kube-vip-#{survivor}" && metadata['namespace'] == 'kube-system' &&
                                                          input.fetch('spec')['nodeName'] == survivor && !metadata.key?('deletionTimestamp')
    uid = metadata.fetch('uid')
    mirror = metadata.fetch('annotations').fetch('kubernetes.io/config.mirror')
    refuse('invalid mirror identity') unless uid.is_a?(String) && uid.match?(%r{\A[0-9a-f-]{36}\z}) && mirror.is_a?(String) && mirror.match?(%r{\A[0-9a-f]{32,64}\z})
    status = input.fetch('status')
    containers = status.fetch('containerStatuses')
    refuse('VIP runtime is not ready') unless status['phase'] == 'Running' && containers.is_a?(Array) && containers.length == 1 &&
                                              containers[0]['name'] == 'kube-vip' && containers[0]['ready'] == true && containers[0].fetch('state').key?('running')
    runtime = containers[0].fetch('containerID')
    refuse('invalid VIP runtime identity') unless runtime.is_a?(String) && runtime.match?(%r{\A[a-z][a-z0-9-]*://[0-9a-f]{12,128}\z})
    puts JSON.generate('schema' => 1, 'kind' => 'nest_api_survivor_vip', 'survivor' => survivor,
                       'vip' => vip, 'survivor_ip' => ip, 'pod_uid' => uid, 'mirror' => mirror,
                       'container_id' => runtime, 'acceptance_recorded' => false)
  else
    refuse('unsupported projector mode')
  end
rescue StandardError
  refuse('unreadable or unsupported observation')
end
