#! /bin/bash
set -e

# Set environment variables
SSH_HOST_KEY_FILE="${SSH_HOST_KEY_FILE:-/keys/host.pem}"
SSH_AUTHORIZED_KEYS_FILE="${SSH_AUTHORIZED_KEYS_FILE:-/keys/host.pem.pub}"

# Generate an SSH key if none is present
if ! [ -f "${SSH_HOST_KEY_FILE}" ]; then
  mkdir -p "`dirname ${SSH_HOST_KEY_FILE}`"
  ssh-keygen -t rsa -b 4096 -f "${SSH_HOST_KEY_FILE}" -N '' -C ''
fi

# Modify the sshd configuration
sed -i -r "s/^(\s*AllowUsers.*)\$/#\1/"                      /etc/ssh/sshd_config
sed -i -r "s/^(\s*AuthorizedKeysFile.*)\$/#\1/"              /etc/ssh/sshd_config
sed -i -r "s/^(\s*ChallengeResponseAuthentication.*)\$/#\1/" /etc/ssh/sshd_config
sed -i -r "s/^(\s*HostKey.*)\$/#\1/"                         /etc/ssh/sshd_config
sed -i -r "s/^(\s*PermitRootLogin.*)\$/#\1/"                 /etc/ssh/sshd_config

printf '\n%s\n' "AuthorizedKeysFile ${SSH_AUTHORIZED_KEYS_FILE}" >> /etc/ssh/sshd_config
printf '\n%s\n' "AllowUsers ${SSH_USER}"                         >> /etc/ssh/sshd_config
printf '\n%s\n' "ChallengeResponseAuthentication no"             >> /etc/ssh/sshd_config
printf '\n%s\n' "HostKey ${SSH_HOST_KEY_FILE}"                   >> /etc/ssh/sshd_config
if ! [ "${SSH_USER}" = "root" ]; then
  printf '\n%s\n' "PermitRootLogin no"                             >> /etc/ssh/sshd_config
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

${command}
