#! /bin/bash
set -e

# Set environment variables
TCP_TUNNEL_REGEX="^\s*TCP_TUNNEL_([_A-Z]+_([0-9]+))=(.+):([0-9]+)\s*$"
SSH_TUNNEL_REGEX="^\s*SSH_TUNNEL_([_A-Z]+_([0-9]+))=(.+):([0-9]+)\[(([^@]+)@)?([^:]+)(:([0-9]+))?\]\s*$"
SSH_IDENTITY_FILE=${SSH_IDENTITY_FILE:-$HOME/.ssh/id_rsa}
SSH_SERVER_CHECK_INTERVAL=${SSH_SERVER_CHECK_INTERVAL:-30}
DEFAULT_SSH_USER=${DEFAULT_SSH_USER:-root}
DEFAULT_BIND_ADDRESS="0.0.0.0"
DEFAULT_SSH_PORT=2222

# Ensure that autossh doesn't fail even if the initial ssh connection fails
export AUTOSSH_GATETIME=0

# Function to open a TCP tunnel with socat
tcp_tunnel() {
  tunnel_name=$1
  bind_address=$2
  bind_port=$3
  service_host=$4
  service_port=$5
  command="/usr/bin/socat -d TCP-LISTEN:${bind_port},bind=${bind_address},fork TCP:${service_host}:${service_port},reuseaddr"
  echo "Opening ${tunnel_name} TCP tunnel (${bind_address}:${bind_port} -> ${service_host}:${service_port})"
  if ${command}; then
    echo "${tunnel_name} TCP tunnel exited normally."
  else
    echo >&2 "${tunnel_name} TCP tunnel exited with code $?."
  fi
}

# Function to open an SSH tunnel
ssh_tunnel() {
  tunnel_name=$1
  bind_address=$2
  bind_port=$3
  service_host=$4
  service_port=$5
  ssh_user=$6
  ssh_host=$7
  ssh_port=$8
  command="/usr/local/bin/autossh -M 0 -T -N"
  if [ "${SSH_DEBUG_LEVEL}" = "1" ]; then
    command="${command} -v"
  fi
  if [ "${SSH_DEBUG_LEVEL}" = "2" ]; then
    command="${command} -v -v"
  fi
  if [ "${SSH_DEBUG_LEVEL}" = "3" ]; then
    command="${command} -v -v -v"
  fi
  command="${command} -o StrictHostKeyChecking=false"
  command="${command} -o UserKnownHostsFile=/dev/null"
  command="${command} -o ServerAliveInterval=${SSH_SERVER_CHECK_INTERVAL}"
  command="${command} -o Port=${ssh_port}"
  command="${command} -o User=${ssh_user}"
  if ! [ -z "${SSH_PASSWORD}" ]; then
    command="/usr/bin/sshpass -p \"${SSH_PASSWORD}\" ${command}"
  else
    command="${command} -o PasswordAuthentication=false"
  fi
  if [ -f "${SSH_IDENTITY_FILE}" ]; then
    command="${command} -o IdentityFile=\"${SSH_IDENTITY_FILE}\""
  fi
  command="${command} -L ${bind_address}:${bind_port}:${service_host}:${service_port} ${ssh_host}"
  echo "Opening ${tunnel_name} SSH tunnel (${bind_address}:${bind_port} -> ${service_host}:${service_port}[${ssh_user}@${ssh_host}:${ssh_port}])"
  if ${command}; then
    echo "${tunnel_name} SSH tunnel exited normally."
  else
    echo "${tunnel_name} SSH tunnel exited with code $?." >&2
  fi
}

# Initialize pids array
pids=()

# Look for insecure tunnel specifications and spawn them
while read -r tunnel_name bind_port service_host service_port ; do
  bind_address=${bind_address:-$DEFAULT_BIND_ADDRESS}
  tcp_tunnel ${tunnel_name} ${bind_address} ${bind_port} ${service_host} ${service_port} &
  pids+=($!)
done < <(env | grep -E "${TCP_TUNNEL_REGEX}" | sed -E "s/${TCP_TUNNEL_REGEX}/\1 \2 \3 \4/")

# Look for secure tunnel specifications and spawn them
while read -r tunnel_name bind_port service_host service_port ssh_user ssh_host ssh_port ; do
  bind_address=${bind_address:-$DEFAULT_BIND_ADDRESS}
  ssh_user=${ssh_user#'o'}
  ssh_port=${ssh_port#'o'}
  ssh_user=${ssh_user:-$DEFAULT_SSH_USER}
  ssh_port=${ssh_port:-$DEFAULT_SSH_PORT}
  ssh_tunnel ${tunnel_name} ${bind_address} ${bind_port} ${service_host} ${service_port} ${ssh_user} ${ssh_host} ${ssh_port} &
  pids+=($!)
done < <(env | grep -E "${SSH_TUNNEL_REGEX}" | sed -E "s/^${SSH_TUNNEL_REGEX}/\1 \2 \3 \4 o\6 \7 o\9/")

# Kill all subprocesses
killprocs() {
  for pid in "${pids[@]}"; do
    echo "Killing tunnel process $pid"
    kill $pid 2>/dev/null
  done
}

trap 'killprocs' EXIT

# Wait on processes and kill them all if any exited
while true; do
  for pid in "${pids[@]}"; do
    if ! kill -0 ${pid} 2>/dev/null; then
      echo "Tunnel process ${pid} not running... exiting"
      exit 1;
    fi
  done
	sleep 1
done
