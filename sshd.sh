#! /bin/bash
set -e

# Set environment variables
SSH_HOST_KEY_FILE="${SSH_HOST_KEY_FILE:-/keys/host.pem}"
SSH_AUTHORIZED_KEYS_FILE="${SSH_AUTHORIZED_KEYS_FILE:-/keys/host.pem.pub}"

# Create the ssh user if specified
if ! [ "${SSH_USER}" = "root" ]; then
  adduser -h / -g '' -s /bin/sh -D -H "${SSH_USER}"
  passwd -u "${SSH_USER}" > /dev/null
fi

# Generate an SSH key if none is present
if ! [ -f "${SSH_HOST_KEY_FILE}" ]; then
  mkdir -p "`dirname ${SSH_HOST_KEY_FILE}`"
  ssh-keygen -t rsa -b 4096 -f "${SSH_HOST_KEY_FILE}" -N '' -C ''
fi

# Construct the sshd command
command="/usr/sbin/sshd -D"
if [ "${SSH_DEBUG_LEVEL}" = "1" ]; then
  command="${command} -d -e"
fi
if [ "${SSH_DEBUG_LEVEL}" = "2" ]; then
  command="${command} -d -d -e"
fi
if [ "${SSH_DEBUG_LEVEL}" = "3" ]; then
  command="${command} -d -d -d -e"
fi
command="${command} -f /etc/ssh/sshd_config"
command="${command} -h ${SSH_HOST_KEY_FILE}"
command="${command} -o AllowUsers=${SSH_USER}"
command="${command} -o AuthorizedKeysFile=${SSH_AUTHORIZED_KEYS_FILE}"
command="${command} -o ChallengeResponseAuthentication=no"
command="${command} -o GatewayPorts=clientspecified"
if ! [ "${SSH_USER}" = "root" ]; then
  command="${command} -o PermitRootLogin=no"
fi
command="${command} -p ${SSH_PORT}"

${command}
