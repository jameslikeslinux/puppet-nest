#!/bin/sh
#
# run_puppet
#
# Initiate a Puppet run without background agent conflicts
#

set -u

# Ordinary callers retain the historical 0/2 success mapping. Update acceptance
# must distinguish an applied catalog from an unchanged repeat. Validate before
# touching the agent service or acquiring a lock.
preserve_detailed_exit=${PUPPET_PRESERVE_DETAILED_EXIT:-false}
case "$preserve_detailed_exit" in
  true|false) ;;
  *)
    printf '%s\n' 'Invalid Puppet detailed-exit selection' >&2
    exit 1
    ;;
esac

restore_launchd_puppet=false
cygwin=false

restore_launchd() {
  if [ "$restore_launchd_puppet" = true ]; then
    /bin/launchctl bootstrap system /Library/LaunchDaemons/org.voxpupuli.puppet.plist >/dev/null 2>&1 || true
  fi
}

trap restore_launchd EXIT

case "$(uname -s)" in
  CYGWIN*)
    # Use the native agent's supported environment wrapper, not Cygwin Ruby.
    # The elevated Windows SSH token does not use Unix sudo/root escalation.
    cygwin=true
    puppet_bin='/cygdrive/c/Program Files/Puppet Labs/Puppet/bin/puppet.bat'
    if [ ! -f "$puppet_bin" ]; then
      echo 'Unable to find native Windows Puppet executable' >&2
      exit 1
    fi
    ;;
  Darwin)
    # Match the managed cron runner; SSH sessions otherwise use US-ASCII,
    # which makes Facter reject non-ASCII Homebrew/application metadata.
    export LANG=en_US.UTF-8
    export LC_ALL=en_US.UTF-8
    puppet_bin=/opt/puppetlabs/bin/puppet

    if [ ! -x "$puppet_bin" ]; then
      puppet_bin=$(command -v puppet 2>/dev/null || true)
    fi

    if [ -z "$puppet_bin" ]; then
      echo 'Unable to find Puppet executable' >&2
      exit 1
    fi

    if /bin/launchctl print system/puppet >/dev/null 2>&1; then
      /bin/launchctl bootout system /Library/LaunchDaemons/org.voxpupuli.puppet.plist
      restore_launchd_puppet=true
    fi
    ;;
  *)
    puppet_bin=$(command -v puppet 2>/dev/null || true)

    if [ -z "$puppet_bin" ] && [ -x /opt/puppetlabs/bin/puppet ]; then
      puppet_bin=/opt/puppetlabs/bin/puppet
    fi

    if [ -z "$puppet_bin" ]; then
      echo 'Unable to find Puppet executable' >&2
      exit 1
    fi

    if command -v systemctl >/dev/null 2>&1 && systemctl -q is-active puppet-run.timer; then
      systemctl stop puppet-run
    fi
    ;;
esac

# PUPPET_EXTRA_ARGS is already shell-quoted by the Bolt plan so it can carry
# optional arguments such as --environment, --noop, or --tags.
puppet_extra_args=${PUPPET_EXTRA_ARGS:-}

run_puppet() {
  if [ "$cygwin" = true ]; then
    powershell.exe -NoProfile -NonInteractive -Command \
      "& 'C:/Program Files/Puppet Labs/Puppet/bin/puppet.bat' agent --test ${puppet_extra_args}; exit \$LASTEXITCODE"
    return $?
  fi
  # shellcheck disable=SC2086
  "$puppet_bin" agent --test $puppet_extra_args
}

# Accepted Agent Request follow-through can fan out into multiple workers.
# Serialize managed Puppet runs per target host so concurrent review-accepted
# tasks wait their turn instead of racing catalog applies and Hermes refreshes.
if command -v flock >/dev/null 2>&1; then
  lock_file=${PUPPET_AGENT_LOCK_FILE:-/tmp/nest-puppet-agent.lock}
  exec 9>"$lock_file"
  if ! flock -n 9; then
    echo "Waiting for Puppet agent lock: $lock_file" >&2
    flock 9
  fi
fi

run_puppet
status=$?

if [ "$status" -eq 2 ] && [ "$preserve_detailed_exit" = false ]; then
  exit 0
fi

exit "$status"
