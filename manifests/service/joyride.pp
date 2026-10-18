# Joyride credentials are supplied by the private Hiera repository. Application
# pods receive only their environment's runtime Secret; database credentials are
# generated separately by CloudNativePG. Never place tokens in public app data.
class nest::service::joyride (
  Sensitive[Hash[String, String]] $runtime_secrets,
  Sensitive[String]              $registry_dockerconfig,
) {
  $django_secret_key_base64     = base64('encode', $runtime_secrets.unwrap['DJANGO_SECRET_KEY']).chomp
  $ops_token_base64             = base64('encode', $runtime_secrets.unwrap['OPS_TOKEN']).chomp
  $delivery_token_base64        = base64('encode', $runtime_secrets.unwrap['DELIVERY_TOKEN']).chomp
  $wmata_api_key_base64         = base64('encode', $runtime_secrets.unwrap['WMATA_API_KEY']).chomp
  $email_host_user_base64       = base64('encode', $runtime_secrets.unwrap['EMAIL_HOST_USER']).chomp
  $email_host_password_base64   = base64('encode', $runtime_secrets.unwrap['EMAIL_HOST_PASSWORD']).chomp
  $registry_dockerconfig_base64 = base64('encode', $registry_dockerconfig.unwrap).chomp
  $bootstrap_script_base64      = base64('encode', file('nest/app/joyride/bootstrap.py'))
}
