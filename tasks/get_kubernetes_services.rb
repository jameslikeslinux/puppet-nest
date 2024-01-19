#!/usr/bin/env ruby

require 'json'

require_relative '../../ruby_task_helper/files/task_helper.rb'

# Fetch Kubernetes service names and URIs with kubectl
class GetKubernetesServices < TaskHelper
  def task(_opts)
    internal = system 'grep -q cluster.local /etc/resolv.conf'
    services = JSON.parse `kubectl get services -A -l james.tl/sidecar=Nest -o json`

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
