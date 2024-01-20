#!/usr/bin/env ruby

require 'json'
require_relative '../../ruby_task_helper/files/task_helper.rb'

# Fetch Kubernetes service names and URIs with kubectl
class GetKubernetesServices < TaskHelper
  def task(_opts)
    return { value: [] } unless File.exist?(ENV['KUBECONFIG'])

    internal = system 'grep -q cluster.local /etc/resolv.conf'
    services = `kubectl get services -A -l 'james.tl/nest in (stage1, puppet)' -o json`

    raise TaskHelper::Error.new('\'kubectl get services\' failed',
                                'nest::get_kubernetes_services/kubectl-failure') unless $?.success?

    JSON.parse!(services)

    {
      value: services['items'].map do |service|
        {
          name: service['metadata']['annotations']['meta.helm.sh/release-name'],
          uri: if internal
                 "#{service['metadata']['name']}.#{service['metadata']['namespace']}.svc.cluster.local"
               else
                 "#{service['metadata']['annotations']['meta.helm.sh/release-name']}.eyrie"
               end
        }
      end
    }
  end
end

if __FILE__ == $PROGRAM_NAME
  GetKubernetesServices.run
end
