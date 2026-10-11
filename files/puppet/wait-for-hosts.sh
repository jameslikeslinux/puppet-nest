#!/bin/sh

set -e

# Respect hosts-file entries as well as DNS for container-local dependencies
wait_for_host_name_resolution() {
  /wtfc.sh --timeout="$2" --interval=1 --progress "getent ahostsv4 '$1'"
  getent ahostsv4 "$1"
}

wait_for_host_port() {
  /wtfc.sh --timeout="$3" --interval=1 --progress "nc -v -w 1 -z '$1' $2"
}

PUPPETDB_WAITFORHOST_SECONDS=${PUPPETDB_WAITFORHOST_SECONDS:-30}
PUPPETDB_WAITFORPOSTGRES_SECONDS=${PUPPETDB_WAITFORPOSTGRES_SECONDS:-60}
PUPPETDB_WAITFORHEALTH_SECONDS=${PUPPETDB_WAITFORHEALTH_SECONDS:-360}
PUPPETDB_POSTGRES_HOSTNAME=${PUPPETDB_POSTGRES_HOSTNAME:-postgres}
PUPPETSERVER_HOSTNAME=${PUPPETSERVER_HOSTNAME:-puppet}
PUPPETSERVER_PORT=${PUPPETSERVER_PORT:-8140}

wait_for_host_name_resolution "$PUPPETDB_POSTGRES_HOSTNAME" "$PUPPETDB_WAITFORHOST_SECONDS"

if [ "$USE_PUPPETSERVER" = true ]; then
  wait_for_host_name_resolution "$PUPPETSERVER_HOSTNAME" "$PUPPETDB_WAITFORHOST_SECONDS"
  HEALTH_COMMAND="curl --silent --fail --insecure 'https://${PUPPETSERVER_HOSTNAME}:${PUPPETSERVER_PORT}/status/v1/simple' | grep -q '^running$'"
fi

if [ -n "$HEALTH_COMMAND" ]; then
  /wtfc.sh --timeout="$PUPPETDB_WAITFORHEALTH_SECONDS" --interval=1 --progress "$HEALTH_COMMAND"
fi

wait_for_host_port "$PUPPETDB_POSTGRES_HOSTNAME" "${PUPPETDB_POSTGRES_PORT:-5432}" "$PUPPETDB_WAITFORPOSTGRES_SECONDS"
