#!/usr/bin/env ruby
# Complete kube-vip's generated health-check configuration before publication.
require 'yaml'

# Go emits the plain YAML scalar :2112 for the Prometheus listen address.
# Psych interprets that as a Ruby Symbol; normalize to ordinary YAML strings
# before emitting portable Kubernetes YAML, without permitting object classes.
manifest = YAML.safe_load($stdin.read, permitted_classes: [Symbol])
spec = manifest.fetch('spec')
container = spec.fetch('containers').find { |item| item.fetch('name') == 'kube-vip' }
container.fetch('env').each { |item| item['value'] = ":#{item['value']}" if item['value'].is_a?(Symbol) }
environment = container.fetch('env').to_h { |item| [item.fetch('name'), item['value']] }
ca = '/etc/kubernetes/pki/ca.crt'
raise 'kube-vip must verify the local API CA' unless environment['control_plane_health_check_ca_path'] == ca
raise 'kube-vip must check strict readiness' unless environment.fetch('control_plane_health_check_address').match?(%r{\Ahttps://[^/]+:6443/readyz\z})

container.fetch('volumeMounts') << { 'name' => 'health-check-ca', 'mountPath' => ca, 'readOnly' => true }
spec.fetch('volumes') << { 'name' => 'health-check-ca', 'hostPath' => { 'path' => ca, 'type' => 'File' } }
puts YAML.dump(manifest)
