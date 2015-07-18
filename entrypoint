#!/bin/bash
set -e

# Look for known command aliases
case "$1" in
  "client" ) shift ; command="/usr/local/bin/tunnel" ;;
  "server" ) shift ; command="/usr/local/bin/sshd" ;;
  * )        command="$@";;
esac

exec ${command}
