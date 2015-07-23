#! /bin/bash
set -e

# Set environment variables
SSH_HOST_KEY_FILE=${SSH_HOST_KEY_FILE:-/etc/ssh/ssh_host_rsa_key}
SSH_AUTHORIZED_KEYS_FILE=${SSH_AUTHORIZED_KEYS_FILE:-/root/.ssh/authorized_keys}

# Generate an SSH key if none is present
if ! [ -f "${SSH_HOST_KEY_FILE}" ]; then
  ssh-keygen -t rsa -b 4096 -f "${SSH_HOST_KEY_FILE}" -N '' -C ''
fi

# Modify the sshd configuration
sed -i -r "s/^(\s*AuthorizedKeysFile.*)\$/#\1/" /etc/ssh/sshd_config
sed -i -r "s/^(\s*HostKey.*)\$/#\1/" /etc/ssh/sshd_config
printf '\n%s\n%s\n' "AuthorizedKeysFile ${SSH_AUTHORIZED_KEYS_FILE}" "HostKey ${SSH_HOST_KEY_FILE}" >> /etc/ssh/sshd_config

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

${command}
