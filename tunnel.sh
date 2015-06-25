#!/bin/sh
set -e

# Look for a TCP and SSH tunnel spec in the environment
tcp_tunnel_spec=$(env | grep _TCP= | head | sed 's/.*_PORT_\([0-9]*\)_TCP=\(tcp:\/\/\)?\(.*\):\([0-9]*\)/echo \1 \3 \4/' | sh)
ssh_tunnel_spec=$(env | grep _SSH= | head | sed 's/.*_PORT_\([0-9]*\)_SSH=\(ssh:\/\/\)?\(.*\):\([0-9]*\)/echo \1 \3 \4/' | sh)

# Return if no tunnel spec found
if [ -z "$tcp_tunnel_spec" ] && [ -z "$ssh_tunnel_spec" ]; then
  echo "Tunnel specification not found in environment"
  exit 1
fi

if ! [ -z "$tcp_tunnel_spec" ]; then

  # Extract invididual variables
  LOCAL_PORT=$(echo $tcp_tunnel_spec | cut -d' ' -f1)
  REMOTE_HOST=$(echo $tcp_tunnel_spec | cut -d' ' -f2)
  REMOTE_PORT=$(echo $tcp_tunnel_spec | cut -d' ' -f3)

  # Open insecure tunnel with socat
  echo "Opening insecure tunnel *:${LOCAL_PORT} -> ${REMOTE_HOST}:${REMOTE_PORT}"
  exec socat TCP4-LISTEN:${LOCAL_PORT},fork,reuseaddr TCP4:${REMOTE_HOST}:${REMOTE_PORT}

else

  # Extract invididual variables
  LOCAL_PORT=$(echo $ssh_tunnel_spec | cut -d' ' -f1)
  REMOTE_HOST=$(echo $ssh_tunnel_spec | cut -d' ' -f2)
  REMOTE_PORT=$(echo $ssh_tunnel_spec | cut -d' ' -f3)

  # Open secure tunnel with SSH
  if [ -f "${SSH_KEY_FILE}" ]; then
    echo "Opening secure tunnel *:${LOCAL_PORT} -> ${REMOTE_HOST}:${REMOTE_PORT} with key"
    exec usr/bin/ssh -T -N \
      -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=false -o ServerAliveInterval=30 -i "${SSH_KEY_FILE}" \
      -L *:${LOCAL_PORT}:${REMOTE_HOST}:${REMOTE_PORT} ${SSH_USER}@${REMOTE_HOST}
  else
    echo "Opening secure tunnel *:${LOCAL_PORT} -> ${REMOTE_HOST}:${REMOTE_PORT}"
    exec usr/bin/ssh -T -N \
      -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=false -o ServerAliveInterval=30 \
      -L *:${LOCAL_PORT}:${REMOTE_HOST}:${REMOTE_PORT} ${SSH_USER}@${REMOTE_HOST}
  fi

fi
