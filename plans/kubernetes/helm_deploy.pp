# Install or upgrade a Helm chart
#
# @param name Installation name
# @param chart Name of the chart to install
# @param namespace Namespace to manage
# @param repo_name Optional name of the Helm repo to add
# @param repo_url Optional URL of the Helm repo to add
# @param version Optional Helm chart version
# @param hooks Enable or disable install hooks
plan nest::kubernetes::helm_deploy (
  String           $name,
  String           $chart = $name,
  Optional[String] $namespace = undef,
  Optional[String] $repo_name = undef,
  Optional[String] $repo_url  = undef,
  Optional[String] $version   = undef,
  Boolean          $hooks     = true,
) {
  if $repo_name and $repo_url {
    $chart_real = "${repo_name}/${chart}"

    $helm_repo_add_cmd = "helm repo add ${repo_name} ${repo_url}"
    run_command($helm_repo_add_cmd, 'localhost', "Add Helm repo ${repo_name} at ${repo_url}")
  } else {
    $chart_real = $chart
  }

  $values_file = find_file("nest/kubernetes/helm/${name}/values.yaml")

  $helm_cmd = [
    'helm', 'upgrade', '--install', $name, $chart_real,

    $hooks ? {
      false   => '--no-hooks',
      default => [],
    },

    $namespace ? {
      undef   => [],
      default => ['--create-namespace', '--namespace', $namespace],
    },

    $values_file ? {
      undef   => [],
      default => ['--values', $values_file],
    },

    $version ? {
      undef   => [],
      default => ['--version', $version],
    },
  ].flatten.join(' ')

  $result = run_command($helm_cmd, 'localhost', "Deploy ${name} from Helm chart ${chart_real}")
}