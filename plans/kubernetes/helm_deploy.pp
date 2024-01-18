# Install or upgrade a Helm chart
#
# @param release Installation name
# @param chart Name of the chart to install
# @param hooks Enable or disable install hooks
# @param namespace Namespace to manage
# @param render_to Just save the fully-rendered chart to this yaml file
# @param repo_name Optional name of the Helm repo to add
# @param repo_url Optional URL of the Helm repo to add
# @param version Optional Helm chart version
plan nest::kubernetes::helm_deploy (
  String           $release,
  String           $chart = $release,
  Boolean          $hooks       = true,
  Optional[String] $namespace   = undef,
  Optional[String] $render_to   = undef,
  Optional[String] $repo_name   = undef,
  Optional[String] $repo_url    = undef,
  Optional[String] $version     = undef,
  Boolean          $wait        = false,
) {
  if $repo_name and $repo_url {
    $chart_real = "${repo_name}/${chart}"

    $helm_repo_add_cmd = "helm repo add ${repo_name} ${repo_url}"
    run_command($helm_repo_add_cmd, 'localhost', "Add Helm repo ${repo_name} at ${repo_url}")
  } else {
    $chart_real = $chart
  }

  apply('localhost') {
    $helm_release = $release
    $helm_chart   = $chart.basename

    include nest::bolt

    file {
      '/tmp/kustomize':
        ensure => directory,
      ;
      '/tmp/kustomize/resources.yaml':
        content => lookup('resources', Array[Hash], 'unique', [{}]).map |$r| { $r.stdlib::to_yaml }.join,
      ;
      '/tmp/kustomize/values.yaml':
        content => lookup('values', Hash, 'deep', {}).stdlib::to_yaml,
      ;
      '/tmp/kustomize/patches.yaml':
        content => lookup('patches', Array[Hash], 'unique', [{}]).map |$r| { $r.stdlib::to_yaml }.join,
      ;
      '/tmp/kustomize/kustomization.yaml':
        source => 'puppet:///modules/nest/kubernetes/kustomization.yaml',
      ;
    }
  }

  $helm_cmd = [
    'helm',

    $render_to ? {
      undef   => ['upgrade', '--install'],
      default => ['template', '--kube-version', '1.28.2'],
    },

    $release, $chart_real,

    $hooks ? {
      false   => '--no-hooks',
      default => [],
    },

    $namespace ? {
      undef   => [],
      default => ['--create-namespace', '--namespace', $namespace],
    },

    '--post-renderer', './scripts/kustomize.sh',
    '--post-renderer-args', '/tmp/kustomize',
    '--values', '/tmp/kustomize/values.yaml',

    $version ? {
      undef   => [],
      default => ['--version', $version],
    },

    $wait ? {
      true    => ['--wait', '--timeout', '1h'],
      default => [],
    },
  ].flatten.shellquote

  if $render_to {
    $redirect = " > ${render_to.shellquote}"
    $cmd_verb = 'Render'
  } else {
    $redirect = ''
    $cmd_verb = 'Deploy'
  }

  run_command("${helm_cmd}${redirect}", 'localhost', "${cmd_verb} ${release} from Helm chart ${chart_real}")
}
