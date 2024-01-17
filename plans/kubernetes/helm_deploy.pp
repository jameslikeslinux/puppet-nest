# Install or upgrade a Helm chart
#
# @param name Installation name
# @param chart Name of the chart to install
# @param namespace Namespace to manage
# @param repo_name Optional name of the Helm repo to add
# @param repo_url Optional URL of the Helm repo to add
# @param version Optional Helm chart version
# @param hooks Enable or disable install hooks
# @param render_to Just save the fully-rendered chart to this yaml file
plan nest::kubernetes::helm_deploy (
  String           $name,
  String           $chart = $name,
  Optional[String] $namespace   = undef,
  Optional[String] $repo_name   = undef,
  Optional[String] $repo_url    = undef,
  Optional[String] $version     = undef,
  Boolean          $hooks       = true,
  Optional[String] $render_to   = undef,
) {
  if $repo_name and $repo_url {
    $chart_real = "${repo_name}/${chart}"

    $helm_repo_add_cmd = "helm repo add ${repo_name} ${repo_url}"
    run_command($helm_repo_add_cmd, 'localhost', "Add Helm repo ${repo_name} at ${repo_url}")
  } else {
    $chart_real = $chart
  }

  # Check if this release should be Kustomized
  $kustomization_file = find_file("nest/kubernetes/helm/${name}/kustomization.yaml")

  # Read and merge chart values
  $static_values = loadyaml("files/kubernetes/helm/${name}/values.yaml", {})
  $values_template = find_template("nest/kubernetes/helm/${name}/values.yaml.epp")
  if $values_template {
    $template_values = epp($values_template).parseyaml
  } else {
    $template_values = {}
  }
  $values = stdlib::to_yaml($static_values + $template_values)

  $helm_cmd = [
    'helm',

    $render_to ? {
      undef   => ['upgrade', '--install'],
      default => ['template', '--kube-version', '1.28.2'],
    },

    $name, $chart_real,

    $hooks ? {
      false   => '--no-hooks',
      default => [],
    },

    $namespace ? {
      undef   => [],
      default => ['--create-namespace', '--namespace', $namespace],
    },

    $kustomization_file ? {
      undef   => [],
      default => [
        '--post-renderer', './scripts/kustomize.sh',
        '--post-renderer-args', dirname($kustomization_file),
      ],
    },

    '--values', '-',

    $version ? {
      undef   => [],
      default => ['--version', $version],
    },
  ].flatten.join(' ')

  if $render_to {
    $redirect = " > ${render_to.shellquote}"
    $cmd_verb = 'Render'
  } else {
    $redirect = ''
    $cmd_verb = 'Deploy'
  }

  run_command("echo ${values.shellquote} | ${helm_cmd}${redirect}", 'localhost', "${cmd_verb} ${name} from Helm chart ${chart_real}")
}
