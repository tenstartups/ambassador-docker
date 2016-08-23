#!/bin/bash
set -e

# Ensure that we expand any tunnel specs with variables in them
while read -r tunnel_spec ; do
  eval "export ${tunnel_spec}"
done < <(env | grep -E "^\s*[^=]+=.+[\$][{][_A-Za-z0-9]+[}].+\s*$")

# Look for known command aliases
case "$1" in
  "client" ) shift ; exec "/usr/local/bin/tunnel" "$@" ;;
  "server" ) shift ; exec "/usr/local/bin/sshd" "$@" ;;
  * )        exec "$@" ;;
esac
