#!/bin/sh
# openvpn learn-address script to manage a hosts-like file
# - intended to allow dnsmasq to resolve openvpn clients
#   addn-hosts=/etc/hosts.openvpn-clients
# - written for openwrt (busybox), but should work most anywhere
#
# Changelog
# 2006-10-13 BDL original
# 2013-21-10 - Do not use absolute paths, to be more cross compatible
#            - Add support for flock locking

PATH=$PATH:/bin:/usr/bin

HOSTS=${HOSTS:-"/etc/hosts.openvpn-clients"}
LOCKFILE=${LOCKFILE:-"/var/run/$(basename "$HOSTS").lock"}

IP="$2"
CN="$3"

case "$1" in
  add|update)
    if [ -z "$IP" -o -z "$CN" ]; then
        echo "$0: IP and/or Common Name not provided" >&2
        exit 0
    fi
  ;;
  delete)
    if [ -z "$IP" ]; then
        echo "$0: IP not provided" >&2
        exit 0
    fi
  ;;
   *)
    echo "$0: unknown operation [$1]" >&2
    exit 1
  ;;
esac


# clean up IP if we can
command -v ipcalc >/dev/null 2>&1 && eval $(ipcalc "$IP")

FQDN="$CN"

(
  # Busybox uses lock instead of flock so choose the correct implementation
  (command -v flock >/dev/null 2>&1 && (flock -x 200)) ||
  (command -v lock >/dev/null 2>&1 && (lock "$LOCKFILE"))

  # busybox mktemp must have exactly six X's
  t=$(mktemp "/tmp/$h.XXXXXX")
  if [ $? -ne 0 ]; then
      echo "$0: mktemp failed" >&2
      exit 1
  fi

  # Try to create hosts file if it does not exist yet
  [ ! -f $HOSTS ] && touch $HOSTS

  case "$1" in

    add|update)
      awk '
          # update/uncomment address|FQDN with new record, drop any duplicates:
          $2 == "'"$FQDN"'" \
              { if (!m) print "'"$IP"'\t'"$FQDN"'"; m=1; next }
          { print }
          END { if (!m) print "'"$IP"'\t'"$FQDN"'" }           # add new address to end
      ' "$HOSTS" > "$t" && cat "$t" > "$HOSTS"
    ;;

    delete)
      awk '
          # no FQDN, comment out all matching addresses (should only be one)
          $1 == "'"$IP"'" { print "#" $0; next }
          { print }
      ' "$HOSTS" > "$t" && cat "$t" > "$HOSTS"
    ;;

  esac

  rm "$t"

  # Busybox uses lock instead of flock so choose the correct implementation
  (command -v flock >/dev/null 2>&1 && false) ||
  (command -v lock >/dev/null 2>&1 && (lock -u "$LOCKFILE"))
) 200>$((command -v flock >/dev/null 2>&1 && (echo $LOCKFILE)) ||
        (command -v lock >/dev/null 2>&1 && (echo "/dev/null")))

# signal dnsmasq to reread hosts file
systemctl reload dnsmasq
