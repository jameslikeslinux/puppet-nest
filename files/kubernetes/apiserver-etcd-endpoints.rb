#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'yaml'

# Project only endpoint and runtime identities. Never print a manifest, Pod,
# parser exception or unrelated argument: either input can contain private data.
def refuse(message)
  warn "API etcd observation refused: #{message}"
  exit 1
end

def endpoints(pod)
  refuse('expected one v1 API Pod') unless pod.is_a?(Hash) && pod['apiVersion'] == 'v1' && pod['kind'] == 'Pod'
  containers = pod.fetch('spec').fetch('containers')
  refuse('expected one API container') unless containers.is_a?(Array) && containers.length == 1 && containers[0]['name'] == 'kube-apiserver'
  container = containers[0]
  command = container.fetch('command')
  args = container.fetch('args', [])
  refuse('invalid API arguments') unless command.is_a?(Array) && !command.empty? && args.is_a?(Array) && (command + args).all? { |arg| arg.is_a?(String) }
  refuse('unexpected API executable') unless ['kube-apiserver', '/usr/local/bin/kube-apiserver', '/usr/bin/kube-apiserver'].include?(command[0])
  flags = (command.drop(1) + args).select { |arg| arg == '--etcd-servers' || arg.start_with?('--etcd-servers=') }
  refuse('expected one explicit etcd endpoint flag') unless flags.length == 1 && flags[0].start_with?('--etcd-servers=')
  values = flags[0].delete_prefix('--etcd-servers=').split(',', -1)
  refuse('expected unique TLS etcd endpoints') unless values.length.between?(1, 7) && values.uniq == values && values.all? { |value| value.match?(%r{\Ahttps://(?:[a-z0-9][a-z0-9.-]*|\[[0-9a-f:]+\]):2379\z}) }
  values.sort
end

begin
  refuse('expected observer and static manifest path') unless ARGV.length == 2 && ARGV[0].match?(%r{\A[a-z0-9][a-z0-9.-]{0,127}\z})
  observer, path = ARGV
  manifest = YAML.safe_load_file(path, permitted_classes: [], permitted_symbols: [], aliases: false)
  live = JSON.parse($stdin.read)
  selected = endpoints(manifest)
  refuse('static and observed API endpoints differ') unless selected == endpoints(live)
  metadata = live.fetch('metadata')
  refuse('unexpected observed Pod identity') unless metadata['name'] == "kube-apiserver-#{observer}" && metadata['namespace'] == 'kube-system' && live.fetch('spec')['nodeName'] == observer
  refuse('terminating observed API Pod') if metadata.key?('deletionTimestamp')
  mirror = metadata.fetch('annotations').fetch('kubernetes.io/config.mirror')
  uid = metadata.fetch('uid')
  refuse('invalid mirror or Pod identity') unless mirror.is_a?(String) && mirror.match?(%r{\A[0-9a-f]{32,64}\z}) && uid.is_a?(String) && uid.match?(%r{\A[0-9a-f-]{36}\z})
  status = live.fetch('status')
  refuse('API Pod is not running') unless status['phase'] == 'Running'
  containers = status.fetch('containerStatuses')
  refuse('expected one API runtime container') unless containers.is_a?(Array) && containers.length == 1 && containers[0]['name'] == 'kube-apiserver'
  refuse('API container is not ready and running') unless containers[0]['ready'] == true && containers[0].fetch('state').key?('running')
  runtime = containers[0].fetch('containerID')
  refuse('invalid API container runtime identity') unless runtime.is_a?(String) && runtime.match?(%r{\A[a-z][a-z0-9-]*://[0-9a-f]{12,128}\z})
  puts JSON.generate('schema' => 1, 'kind' => 'nest_apiserver_etcd_endpoints', 'observer' => observer,
                     'endpoints' => selected, 'pod_uid' => uid, 'mirror' => mirror, 'container_id' => runtime,
                     'acceptance_recorded' => false)
rescue StandardError
  refuse('unreadable or unsupported API configuration or Pod response')
end
