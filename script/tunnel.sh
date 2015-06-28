#! /bin/bash
set -e

# Set environment variables
TCP_TUNNEL_REGEX="^\s*TCP_TUNNEL_([A-Z]+_([0-9]+))=(.+):([0-9]+)"
SSH_TUNNEL_REGEX="^\s*SSH_TUNNEL_([A-Z]+_([0-9]+))=(.+):([0-9]+)\[([^:]+)(:([0-9]+))?\]"
SSH_IDENTITY_FILE=${SSH_IDENTITY_FILE:-$HOME/.ssh/id_rsa}
SSH_SERVER_CHECK_INTERVAL=${SSH_SERVER_CHECK_INTERVAL:-30}
SSH_USER=${SSH_USER:-root}
DEFAULT_BIND_ADDRESS="0.0.0.0"
DEFAULT_SSH_PORT=2222

# Function to open a TCP tunnel with socat
tcp_tunnel() {
  tunnel_name=$1
  bind_address=$2
  bind_port=$3
  service_host=$4
  service_port=$5
  gracefully_exit=false
  trap 'gracefully_exit=true' SIGINT SIGQUIT
  command="/usr/bin/socat -d TCP-LISTEN:$bind_port,bind=$bind_address,fork TCP:$service_host:$service_port,reuseaddr"
  echo "Opening $tunnel_name TCP tunnel ($bind_address:$bind_port -> $service_host:$service_port)"
  until $command; do
    if [ "$gracefully_exit" = "true" ]; then break; fi
    echo "$tunnel_name TCP tunnel exited with code $?.  Restarting..." >&2
    sleep 1
  done
}

# Function to open an SSH tunnel
ssh_tunnel() {
  tunnel_name=$1
  bind_address=$2
  bind_port=$3
  service_host=$4
  service_port=$5
  ssh_host=$6
  ssh_port=$7
  gracefully_exit=false
  trap 'gracefully_exit=true' SIGINT SIGQUIT
  command="/usr/bin/ssh -T -N"
  if [ "${SSH_DEBUG_LEVEL}" = "1" ]; then
    command="$command -v"
  fi
  if [ "${SSH_DEBUG_LEVEL}" = "2" ]; then
    command="$command -v -v"
  fi
  if [ "${SSH_DEBUG_LEVEL}" = "3" ]; then
    command="$command -v -v -v"
  fi
  command="$command -o StrictHostKeyChecking=false"
  command="$command -o ServerAliveInterval=${SSH_SERVER_CHECK_INTERVAL}"
  command="$command -o Port=$ssh_port"
  command="$command -o User=${SSH_USER}"
  if ! [ -z "${SSH_PASSWORD}" ]; then
    command="/usr/bin/sshpass -p \"${SSH_PASSWORD}\" $command"
  else
    command="$command -o PasswordAuthentication=false"
  fi
  if [ -f "${SSH_IDENTITY_FILE}" ]; then
    command="$command -o IdentityFile=\"${SSH_IDENTITY_FILE}\""
  fi
  command="$command -L $bind_address:$bind_port:$service_host:$service_port $ssh_host"
  echo "Opening $tunnel_name SSH tunnel ($bind_address:$bind_port -> $service_host:$service_port[$ssh_host:$ssh_port])"
  until $command; do
    if [ "$gracefully_exit" = "true" ]; then break; fi
    echo "$tunnel_name SSH tunnel exited with code $?.  Restarting..." >&2
    sleep 1
  done
}

pids=()

# Look for insecure tunnel specifications and spawn them
while read -r tunnel_name bind_port service_host service_port ; do
  bind_address=${bind_address:-$DEFAULT_BIND_ADDRESS}
  tcp_tunnel $tunnel_name $bind_address $bind_port $service_host $service_port &
done < <(env | grep -E "${TCP_TUNNEL_REGEX}" | sed -E "s/${TCP_TUNNEL_REGEX}/\1 \2 \3 \4/")

# Look for secure tunnel specifications and spawn them
while read -r tunnel_name bind_port service_host service_port ssh_host ssh_port ; do
  bind_address=${bind_address:-$DEFAULT_BIND_ADDRESS}
  ssh_port=${ssh_port:-$DEFAULT_SSH_PORT}
  ssh_tunnel $tunnel_name $bind_address $bind_port $service_host $service_port $ssh_host $ssh_port &
done < <(env | grep -E "${SSH_TUNNEL_REGEX}" | sed -E "s/^${SSH_TUNNEL_REGEX}/\1 \2 \3 \4 \5 \7/")

# Wait for all spawned processes to complete
for pid in `jobs -p`; do
  wait $pid
done
