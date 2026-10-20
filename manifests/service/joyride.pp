# Joyride credentials are supplied by the private Hiera repository. Application
# pods receive only their environment's runtime Secret; database credentials are
# generated separately by CloudNativePG. Never place tokens in public app data.
class nest::service::joyride (
  Optional[Sensitive[Hash[String, String]]] $runtime_secrets         = undef,
  Optional[Sensitive[String]]               $registry_dockerconfig   = undef,
  Optional[Sensitive[String]]               $artifact_verifier_token = undef,
) {
  # Only the verified TEST recipe exists. A distinct production contract and
  # owner-approved rollout must be implemented before this boundary is widened.
  if $nest::kubernetes::namespace != 'test' or $nest::kubernetes::service != 'joyride-test' or lookup('runtime_environment', { 'default_value' => undef }) != 'test' {
    fail('Joyride currently supports only service joyride-test in namespace test with runtime_environment test; production is not configured')
  }

  # Reject an unsupported environment before asking for credentials. Optional
  # parameters permit that ordering, not a credential-free TEST deployment.
  if $runtime_secrets == undef or $registry_dockerconfig == undef or $artifact_verifier_token == undef {
    fail('Joyride TEST requires managed runtime, registry and artifact-verifier credentials')
  }

  $django_secret_key_base64      = base64('encode', $runtime_secrets.unwrap['DJANGO_SECRET_KEY']).chomp
  $ops_token_base64              = base64('encode', $runtime_secrets.unwrap['OPS_TOKEN']).chomp
  $delivery_token_base64         = base64('encode', $runtime_secrets.unwrap['DELIVERY_TOKEN']).chomp
  $wmata_api_key_base64          = base64('encode', $runtime_secrets.unwrap['WMATA_API_KEY']).chomp
  $email_host_user_base64        = base64('encode', $runtime_secrets.unwrap['EMAIL_HOST_USER']).chomp
  $email_host_password_base64    = base64('encode', $runtime_secrets.unwrap['EMAIL_HOST_PASSWORD']).chomp
  $registry_dockerconfig_base64  = base64('encode', $registry_dockerconfig.unwrap).chomp
  $bootstrap_script_base64       = base64('encode', file('nest/app/joyride/bootstrap.py'))
  $verifier_token_base64         = base64('encode', $artifact_verifier_token.unwrap).chomp
  $artifact_import_base64        = base64('encode', file('nest/app/joyride/import_artifacts.py'))
  $test_delivery_base64          = base64('encode', file('nest/app/joyride/test_delivery_controller.py'))
  $test_access_config_base64     = base64('encode', file('nest/app/joyride/test-access-nginx.conf'))
  $test_access_config_sha256     = sha256(file('nest/app/joyride/test-access-nginx.conf'))
  $backup_script_base64          = base64('encode', file('nest/app/joyride/backup.py'))
  $monitor_script_base64         = base64('encode', file('nest/app/joyride/monitor.py'))
  $production_ops_config_base64  = base64('encode', file('nest/app/joyride/production-ops-nginx.conf'))
  $production_ops_config_sha256  = sha256(file('nest/app/joyride/production-ops-nginx.conf'))
}
