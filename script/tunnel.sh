#! /bin/bash
set -e

# Set environment variables
TCP_TUNNEL_REGEX="^\s*TCP_TUNNEL_([A-Z]+_([0-9]+))=(.+):([0-9]+)"
SSH_TUNNEL_REGEX="^\s*SSH_TUNNEL_([A-Z]+_([0-9]+))=(.+):([0-9]+)"

SSH_REMOTE_PORT=${SSH_REMOTE_PORT:-2222}
SSH_IDENTITY_FILE=${SSH_IDENTITY_FILE:-$HOME/.ssh/id_rsa}
SSH_SERVER_CHECK_INTERVAL=${SSH_SERVER_CHECK_INTERVAL:-30}
SSH_USER=${SSH_USER:-root}

# Function to open a TCP tunnel with socat
tcp_tunnel() {
  tunnel_name=$1
  local_port=$2
  remote_host=$3
  remote_port=$4
  exit_loop=0
  trap 'exit_loop=1' SIGINT SIGQUIT
  command="/usr/bin/socat -d -d TCP4-LISTEN:$local_port,fork,reuseaddr TCP4:$remote_host:$remote_port"
  echo "Opening $tunnel_name TCP tunnel (*:$local_port -> $remote_host:$remote_port)"
  until $command; do
    if [ "$exit_loop" = 1 ]; then break; fi
    echo "$tunnel_name TCP tunnel exited with code $?.  Restarting..." >&2
    sleep 1
  done
}

# Function to open an SSH tunnel
ssh_tunnel() {
  tunnel_name=$1
  local_port=$2
  remote_host=$3
  remote_port=$4
  exit_loop=0
  trap 'exit_loop=1' SIGINT SIGQUIT
  command="/usr/bin/ssh -T -N"
  command="$command -o StrictHostKeyChecking=false"
  command="$command -o ServerAliveInterval=${SSH_SERVER_CHECK_INTERVAL}"
  command="$command -o Port=${SSH_REMOTE_PORT}"
  command="$command -o User=${SSH_USER}"
  if ! [ -z "${SSH_PASSWORD}" ]; then
    command="/usr/bin/sshpass -p \"${SSH_PASSWORD}\" $command"
  else
    command="$command -o PasswordAuthentication=false"
  fi
  if [ -f "${SSH_IDENTITY_FILE}" ]; then
    command="$command -o IdentityFile=\"${SSH_IDENTITY_FILE}\""
  fi
  command="$command -L *:$local_port:$remote_host:$remote_port $remote_host"
  echo "Opening $tunnel_name SSH tunnel (*:$local_port -> $remote_host:$remote_port)"
  until $command; do
    if [ "$exit_loop" = 1 ]; then break; fi
    echo "$tunnel_name SSH tunnel exited with code $?.  Restarting..." >&2
    sleep 1
  done
}

pids=()

# Look for insecure tunnel specifications and spawn them
while read -r tunnel_name local_port remote_host remote_port ; do
  tcp_tunnel $tunnel_name $local_port $remote_host $remote_port &
done < <(env | grep -E "${TCP_TUNNEL_REGEX}" | sed -E "s/${TCP_TUNNEL_REGEX}/\1 \2 \3 \4/")

# Look for secure tunnel specifications and spawn them
while read -r tunnel_name local_port user password_or_identity_file remote_host ssh_port remote_port ; do
  ssh_tunnel $tunnel_name $local_port $remote_host $ssh_port $remote_port $user $password_or_identity_file &
done < <(env | grep -E "${SSH_TUNNEL_REGEX}" | sed -E "s/^${SSH_TUNNEL_REGEX}/\1 \2 \3 \4 \5 \6 \7/")

# Wait for all spawned processes to complete
for pid in `jobs -p`; do
  wait $pid
done
