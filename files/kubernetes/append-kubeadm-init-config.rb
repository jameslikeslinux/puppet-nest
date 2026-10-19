#!/usr/bin/env ruby
# Preserve the member endpoint and apply patches through InitConfiguration.
require 'yaml'

config_path, manifest_path, patches = ARGV
raise 'expected config, manifest and patches paths' unless ARGV.length == 3

cluster = YAML.safe_load_file(config_path)
raise 'expected ClusterConfiguration' unless cluster.fetch('kind') == 'ClusterConfiguration'
raise 'unsupported kubeadm schema' unless ['kubeadm.k8s.io/v1beta3', 'kubeadm.k8s.io/v1beta4'].include?(cluster.fetch('apiVersion'))

manifest = YAML.safe_load_file(manifest_path)
container = manifest.fetch('spec').fetch('containers').find { |item| item.fetch('name') == 'kube-apiserver' }
arguments = container.fetch('command').grep(%r{\A--(?:advertise-address|secure-port)=})
values = arguments.to_h { |argument| argument.delete_prefix('--').split('=', 2) }
raise 'ambiguous API endpoint arguments' unless arguments.length == values.length

init = {
  'apiVersion' => cluster.fetch('apiVersion'),
  'kind' => 'InitConfiguration',
  'localAPIEndpoint' => {
    'advertiseAddress' => values.fetch('advertise-address'),
    'bindPort' => Integer(values.fetch('secure-port')),
  },
  'patches' => { 'directory' => patches },
}
File.write(config_path, YAML.dump(cluster) + YAML.dump(init))
