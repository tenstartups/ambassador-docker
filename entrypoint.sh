#!/bin/sh
set -e

# Create the ambassador user if specified
if [ "${AMBASSADOR_USER}" != "root" ]; then
  adduser -h / -g '' -s /bin/sh -D -H "${AMBASSADOR_USER}"
  passwd -u "${AMBASSADOR_USER}"
fi

# Generate an SSH key if none is present
if ! [ -f "${SSH_HOST_KEY_FILE}" ]; then
  mkdir -p "`dirname ${SSH_HOST_KEY_FILE}`"
  ssh-keygen -t rsa -b 4096 -f "${SSH_HOST_KEY_FILE}" -N '' -C ''
fi

# Expand environment variables and re-export
while read -r environment ; do
  eval "export ${environment}"
done < <(env | grep -E "^\s*[^=]+=.+[\$][{][_A-Za-z0-9]+[}].+\s*$")

# Create Chaperone service configurations
/usr/local/bin/create_service_configs

if [ -z "$@" ]; then
  exec /usr/bin/chaperone
else
  exec "$@"
fi
