class nest::service::gitlab_runner (
  String             $registration_token,
  Hash[String, Hash] $instances = {},
) {
  nest::lib::srv { 'gitlab-runner': }

  $instances.each |$instance, $attributes| {
    nest::lib::gitlab_runner { $instance:
      registration_token => $registration_token,
      require            => Nest::Lib::Srv['gitlab-runner'],
      *                  => $attributes,
    }
  }
}
