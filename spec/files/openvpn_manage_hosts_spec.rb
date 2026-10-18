# frozen_string_literal: true

require 'open3'
require 'tmpdir'

RSpec.describe 'OpenVPN host hooks' do
  ['client-connect.sh', 'client-disconnect.sh'].each do |hook|
    it "queues DNS reloads without waiting for systemd jobs in #{hook}" do
      Dir.mktmpdir('openvpn-hosts') do |directory|
        hosts = File.join(directory, 'hosts')
        calls = File.join(directory, 'calls')
        systemctl = File.join(directory, 'systemctl')
        script = File.join(directory, hook)
        File.write(hosts, "192.0.2.1\told-client\n192.0.2.2\ttest-client\n192.0.2.3\tother-client\n")
        # Model a reload queued behind a job that cannot finish until the hook
        # returns. Refuse a synchronous wait rather than hanging the test.
        File.write(systemctl, "#!/bin/sh\nprintf '%s\\n' \"$*\" >> \"$CALLS\"\n[ \"$*\" = '--no-block reload dnsmasq' ] || exit 75\n")
        File.chmod(0o755, systemctl)
        source = File.read(File.expand_path('../../files/openvpn/manage-hosts.sh', __dir__))
        File.write(script, source.gsub('/bin/systemctl', systemctl))
        env = { 'HOSTS' => hosts, 'CALLS' => calls, 'common_name' => 'test-client', 'ifconfig_pool_remote_ip' => '192.0.2.1' }

        stdout, stderr, status = Open3.capture3(env, 'bash', script)

        expect(status.success?).to be(true), "Hook failed: #{stdout}#{stderr}"
        expect(File.readlines(calls).map(&:strip)).to all(eq('--no-block reload dnsmasq'))
        expect(File.read(hosts)).to include("192.0.2.3\tother-client\n")
        expect(File.read(hosts)).not_to include('old-client', '192.0.2.2')
        if hook == 'client-connect.sh'
          expect(File.read(hosts)).to include("192.0.2.1\ttest-client\n")
        else
          expect(File.read(hosts)).not_to include('test-client', '192.0.2.1')
        end
      end
    end
  end
end
