#!/bin/bash
set -e

# Export environment
export SSH_USER="${SSH_USER:-ambassador}"

# Create the ssh user if specified
if ! [ "${SSH_USER}" = "root" ]; then
  adduser -h / -g '' -s /bin/sh -D -H "${SSH_USER}"
  passwd -u "${SSH_USER}" > /dev/null
fi

# Look for known command aliases
case "$1" in
  "client" ) shift ; exec su "${SSH_USER}" -c "/usr/local/bin/tunnel" "$@" ;;
  "server" ) shift ; exec "/usr/local/bin/sshd" "$@" ;;
  * )        exec "$@" ;;
esac
