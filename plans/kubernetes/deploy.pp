# Install or upgrade a service with Helm and Kustomize
#
# @param service Installation name
# @param app Name of the app to install
# @param append How `render_to` should be written out
# @param chart Chart name if it doesn't match `app`
# @param deploy Run or skip the deployment
# @param hooks Enable or disable install hooks
# @param namespace Namespace to manage
# @param render_to Just save the fully-rendered chart to this yaml file
# @param repo_name Optional name of the Helm repo to add
# @param repo_url Optional URL of the Helm repo to add
# @param version Optional Helm chart version
# @param restore Masks backup job during restore deployment
# @param wait Wait for resources to become available
# @param subcharts Additional apps and services to deploy with this one
# @param parent Private. The parent service this one is being rendered for.
plan nest::kubernetes::deploy (
  String           $service,
  String           $app       = $service,
  Boolean          $append    = false,
  String           $chart     = $app,
  Boolean          $deploy    = true,
  Boolean          $hooks     = true,
  Optional[String] $namespace = undef,
  Optional[String] $render_to = undef,
  Optional[String] $repo_name = undef,
  Optional[String] $repo_url  = undef,
  Optional[String] $version   = undef,
  Boolean          $restore   = false,
  Boolean          $wait      = false,
  Array[Hash]      $subcharts = [],
  Optional[String] $parent    = undef,
) {
  if $deploy {
    $subcharts.each |$subchart| {
      run_plan('nest::kubernetes::deploy', $subchart + {
        parent    => $service,
        namespace => $namespace,
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

    # Because YAML plans
    if $render_to and $render_to != '' {
      $render_to_real = $render_to
    } else {
      $render_to_real = undef
    }

    apply('localhost') {
      $kubernetes_service        = $service
      $kubernetes_app            = $app
      $kubernetes_namespace      = $namespace
      $kubernetes_parent_service = $parent

      include nest::bolt # for lookups

      if $restore {
        $backup_resources = ['backup']
      } else {
        $backup_resources = []
      }

      $resources = lookup('resources') - $backup_resources
      $values    = lookup('values')
      $patches   = lookup('patches')

      file {
        '/tmp/kustomize':
          ensure => directory;
        '/tmp/kustomize/subcharts.yaml':
          ensure => file;
        '/tmp/kustomize/resources.yaml':
          content => $resources.values.flatten.map |$r| { if $r.empty { '' } else { $r.stdlib::to_yaml } }.join;
        '/tmp/kustomize/values.yaml':
          content => $values.stdlib::to_yaml;
        '/tmp/kustomize/kustomization.yaml':
          content => {
            'resources' => ['subcharts.yaml', 'resources.yaml', 'helm.yaml'],
            'patches'   => $patches.keys.sort.map |$k| { $patches[$k] }.flatten.map |$p| {
              if $p['patch'] =~ String {
                $p
              } else {
                $p + { 'patch' => $p['patch'].stdlib::to_yaml }
              }
            },
          }.stdlib::to_yaml,
        ;
      }
    }

    $helm_cmd = [
      'helm',

      $render_to_real ? {
        undef   => ['upgrade', '--install'],
        default => ['template', '--kube-version', '1.28.2'],
      },

      $service, $chart_real,

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

      ($wait and !$render_to_real) ? {
        true    => ['--wait', '--timeout', '1h'],
        default => [],
      },
    ].flatten.shellquote

    if $render_to_real {
      if $append {
        $redirect_op = '>>'
      } else {
        $redirect_op = '>'
      }
      $redirect = " ${redirect_op} ${render_to_real.shellquote}"
      $cmd_verb = 'Render'
    } else {
      $redirect = ''
      $cmd_verb = 'Deploy'
    }

    run_command("${helm_cmd}${redirect}", 'localhost', "${cmd_verb} ${service} from Helm chart ${chart_real}")

    # Give time for VIP to propagate
    if $wait and !$render_to_real {
      ctrl::sleep(10)
    }
  }
}
