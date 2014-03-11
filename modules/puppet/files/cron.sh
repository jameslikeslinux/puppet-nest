#!/bin/sh
/usr/bin/puppet agent --onetime --no-daemonize --splay > /dev/null 2>&1
