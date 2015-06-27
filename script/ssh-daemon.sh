#! /bin/bash
set -e

# Set environment variables
SSH_HOST_KEY_FILE=${SSH_HOST_KEY_FILE:-/etc/ssh/ssh_host_rsa_key}

command="/usr/sbin/sshd -D"
if [ "${SSH_DEBUG}" = "1" ]; then
  command="$command -d -e"
fi
if [ "${SSH_DEBUG}" = "2" ]; then
  command="$command -d -d -e"
fi
if [ "${SSH_DEBUG}" = "3" ]; then
  command="$command -d -d -d -e"
fi
command="$command -h ${SSH_HOST_KEY_FILE}"

$command
