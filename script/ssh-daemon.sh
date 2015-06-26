#! /bin/bash
set -e

command="/usr/sbin/sshd -D"
if [ "${SSH_DEBUG}" = "true" ]; then
  command="$command -v"
fi

$command
