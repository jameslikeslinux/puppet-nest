#!/usr/bin/env ruby

require 'English'
require 'json'
require_relative '../../ruby_task_helper/files/task_helper.rb'

# Fetch Kubernetes service names and URIs with kubectl
class GetKubernetesServices < TaskHelper
  def task(_opts)
    services = `kubectl get services -A -l 'james.tl/nest in (stage1, puppet)' -o json`
    return { value: [] } unless $CHILD_STATUS.success?
    services = JSON.parse(services)

    {
      value: services['items'].map do |service|
        {
          name: service['metadata']['annotations']['meta.helm.sh/release-name'],
          uri: "#{service['metadata']['name']}.#{service['metadata']['namespace']}.svc.cluster.local",
          config: { ssh: { proxyjump: 'jump.eyrie', user: 'james' } },
        }
      end
    }
  end
end

if __FILE__ == $PROGRAM_NAME
  GetKubernetesServices.run
end
