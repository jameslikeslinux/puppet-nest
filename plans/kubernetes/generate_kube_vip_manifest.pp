# Generate kube-vip static pod manifest
#
# @param targets Nodes to generate config on
# @param vip Virtual IP address to advertise
# @param advertise Whether the targets should advertise the control-plane VIP
# @param survivor Healthy advertiser that must survive withdrawal or replacement
# @param maintenance External client, advertisers, physical domains and Ceph identity for maintenance admission
#
# @see https://kube-vip.io/docs/installation/static/
plan nest::kubernetes::generate_kube_vip_manifest (
  TargetSpec              $targets,
  Stdlib::IP::Address::V4 $vip,
  String                  $version     = 'v1.2.4',
  Boolean                 $advertise   = true,
  Optional[String]        $survivor    = undef,
  Optional[Hash]          $maintenance = undef,
) {
  $nodes = get_targets($targets)
  $existing = run_command('if test -s /etc/kubernetes/manifests/kube-vip.yaml; then printf present; else printf absent; fi', $nodes, 'Classify existing VIP manifests before mutation', {
    _run_as => 'root',
  }).filter |$result| { $result.value['stdout'].chomp == 'present' }
  if !$advertise or !$existing.empty {
    if $nodes.length != 1 or !($survivor in ['control1', 'control2', 'control3']) or $survivor == $nodes[0].name {
      fail('VIP withdrawal or replacement requires exactly one target and a different explicit control-plane survivor')
    }
    if $maintenance == undef or $maintenance.keys.sort != ['advertisers', 'ceph_fsid', 'client', 'physical_domains'] {
      fail_plan('VIP maintenance requires exact client, advertiser, physical-domain and Ceph inputs', 'nest/maintenance-scope')
    }
    run_plan('nest::kubernetes::check_control_plane_maintenance', $maintenance + {
      'target'   => $nodes[0].name,
      'survivor' => $survivor,
      'vip'      => $vip,
    })
  }

  parallelize($nodes) |$t| {
    # XXX Generalize this
    $bgp_peers = $t.name ? {
      'control1' => ['172.22.4.8', '172.22.4.9'],
      'control2' => ['172.22.4.7', '172.22.4.9'],
      'control3' => ['172.22.4.7', '172.22.4.8'],
      default    => fail("Can't determine BGP peers for ${t.name}")
    }

    $kube_vip_cmd_quoted = [
      '/usr/bin/podman', 'run', '--network', 'host', '--rm', "ghcr.io/kube-vip/kube-vip:${version}",
      'manifest', 'pod',
      '--interface', 'lo',
      '--address', $vip,
      '--controlplane',
      # Native BGP gating: never advertise before the first strict local
      # readiness success; withdraw on consecutive failures, recover on health.
      '--controlPlaneHealthCheckAddress', "https://${t.name}:6443/readyz",
      '--controlPlaneHealthCheckCAPath', '/etc/kubernetes/pki/ca.crt',
      '--controlPlaneHealthCheckPeriodSeconds', '10',
      '--controlPlaneHealthCheckTimeoutSeconds', '3',
      '--controlPlaneHealthCheckFailureThreshold', '2',
      '--bgp',
      '--localAS', '65000',
      '--bgppeers', $bgp_peers.map |$p| { "${p}:65000::false" }.join(','),
    ].flatten.shellquote

    # Upstream manifest generation emits the CA setting but not its mount.
    $qualify_command = ['ruby', '-e', file('nest/kubernetes/kube-vip-health-ca.rb')].shellquote
    $render_command = @(COMMAND/L)
      set -eu
      manifest=/etc/kubernetes/manifests/kube-vip.yaml
      temporary="$(mktemp /etc/kubernetes/manifests/.kube-vip.XXXXXX.yaml)"
      qualified="$(mktemp /etc/kubernetes/manifests/.kube-vip-qualified.XXXXXX.yaml)"
      trap 'rm -f "$temporary" "$qualified"' EXIT
      __KUBE_VIP__ --bgpRouterID "$(facter networking.ip)" > "$temporary"
      __QUALIFY__ < "$temporary" > "$qualified"
      mv -f "$qualified" "$temporary"
      test -s "$temporary"
      if [ -f "$manifest" ]; then
        backup_dir=/root/kubernetes-manifest-backups
        install -d -m 0700 "$backup_dir"
        install -m 0600 "$manifest" "$backup_dir/kube-vip-$(date -u +%Y%m%dT%H%M%S.%N).yaml"
      fi
      chmod 0600 "$temporary"
      mv -f "$temporary" "$manifest"
      | COMMAND
    $kube_vip_cmd = $render_command.regsubst('__KUBE_VIP__', $kube_vip_cmd_quoted, 'G')
      .regsubst('__QUALIFY__', $qualify_command, 'G')

    if $advertise {
      run_command($kube_vip_cmd, $t, 'Generate kube-vip pod manifest', {
        _run_as => 'root',
      })
    } else {
      $remove_command = @(COMMAND/L)
        set -eu
        manifest=/etc/kubernetes/manifests/kube-vip.yaml
        if [ -e "$manifest" ]; then
          backup_dir=/root/kubernetes-manifest-backups
          install -d -m 0700 "$backup_dir"
          timestamp="$(date -u +%Y%m%dT%H%M%S.%N)"
          install -m 0600 "$manifest" "$backup_dir/kube-vip-${timestamp}.yaml"
          rm "$manifest"
        fi
        | COMMAND
      run_command($remove_command, $t, 'Stop advertising kube-vip from excluded member', {
        _run_as => 'root',
      })
    }
  }
}
