# Install or upgrade a Helm chart
#
# @param release Installation name
# @param chart Name of the chart to install
# @param append How `render_to` should be written out
# @param hooks Enable or disable install hooks
# @param namespace Namespace to manage
# @param render_to Just save the fully-rendered chart to this yaml file
# @param repo_name Optional name of the Helm repo to add
# @param repo_url Optional URL of the Helm repo to add
# @param version Optional Helm chart version
plan nest::kubernetes::helm_deploy (
  String           $release,
  String           $chart       = $release,
  Boolean          $append      = false,
  Boolean          $hooks       = true,
  Optional[String] $namespace   = undef,
  Optional[String] $render_to   = undef,
  Optional[String] $repo_name   = undef,
  Optional[String] $repo_url    = undef,
  Optional[String] $version     = undef,
  Boolean          $wait        = false,
  Hash             $subcharts   = {},
) {
  $subcharts.each |$subrelease, $params| {
    run_plan('nest::kubernetes::helm_deploy', $params + {
      render_to => '/tmp/kustomize/subcharts.yaml',
      append    => true,
    })
  }

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

    $patches = lookup('patches', Hash, 'deep', {}).map |$patch_name, $patch| {
      file { "/tmp/kustomize/patches/${patch_name}.yaml":
        content => $patch.stdlib::to_yaml,
      }
      $patch_name
    }

    file {
      ['/tmp/kustomize', '/tmp/kustomize/patches']:
        ensure => directory,
        purge  => true,
        force  => true,
      ;
      '/tmp/kustomize/subcharts.yaml':
        content => {}.stdlib::to_yaml,
        replace => false,
      ;
      '/tmp/kustomize/resources.yaml':
        content => lookup('resources', Array[Hash], 'unique', [{}]).map |$r| { $r.stdlib::to_yaml }.join,
      ;
      '/tmp/kustomize/values.yaml':
        content => lookup('values', Hash, 'deep', {}).stdlib::to_yaml,
      ;
      '/tmp/kustomize/kustomization.yaml':
        content => {
          'resources' => ['subcharts.yaml', 'resources.yaml', 'helm.yaml'],
          'patches'   => $patches.map |$patch| { { 'path' => "patches/${patch}.yaml" } },
        }.stdlib::to_yaml,
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
    if $append {
      $redirect_op = '>>'
    } else {
      $redirect_op = '>'
    }
    $redirect = " ${redirect_op} ${render_to.shellquote}"
    $cmd_verb = 'Render'
  } else {
    $redirect = ''
    $cmd_verb = 'Deploy'
  }

  run_command("${helm_cmd}${redirect}", 'localhost', "${cmd_verb} ${release} from Helm chart ${chart_real}")
}
