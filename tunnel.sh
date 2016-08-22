#! /bin/bash
set -e

# Set environment variables
TCP_TUNNEL_REGEX="^\s*TCP_TUNNEL_([_A-Z0-9]+_([0-9]+))=(.+):([0-9]+)\s*$"
SSH_TUNNEL_REGEX="^\s*SSH_(REMOTE_|LOCAL_)?TUNNEL_([_A-Z0-9]+_([0-9]+))=(.+):([0-9]+)\[([^@]+@)?([^:]+)(:[0-9]+)?\]\s*$"
SSH_IDENTITY_FILE="${SSH_IDENTITY_FILE:-$HOME/.ssh/id_rsa}"
SSH_SERVER_CHECK_INTERVAL=${SSH_SERVER_CHECK_INTERVAL:-30}
BIND_ADDRESS="0.0.0.0"

# Ensure that autossh doesn't fail even if the initial ssh connection fails
export AUTOSSH_GATETIME=0

# Ensure that we expand any tunnel specs with variables in them
while read -r tunnel_spec ; do
  eval "export ${tunnel_spec}"
done < <(env | grep -E -e "${TCP_TUNNEL_REGEX}" -e "${SSH_TUNNEL_REGEX}")

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
  tunnel_type=$1
  tunnel_name=$2
  bind_address=$3
  bind_port=$4
  service_host=$5
  service_port=$6
  ssh_user=$7
  ssh_host=$8
  ssh_port=$9
  if [ "${tunnel_type}" = "REMOTE" ]; then
    tunnel_desc="${tunnel_name} SSH remote tunnel"
  else
    tunnel_desc="${tunnel_name} SSH local tunnel"
  fi
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
  command="${command} -o StrictHostKeyChecking=no"
  command="${command} -o UserKnownHostsFile=/dev/null"
  command="${command} -o ServerAliveInterval=${SSH_SERVER_CHECK_INTERVAL}"
  command="${command} -o Port=${ssh_port}"
  command="${command} -o User=${ssh_user}"
  if ! [ -z "${SSH_PASSWORD}" ]; then
    command="/usr/bin/sshpass -p \"${SSH_PASSWORD}\" ${command}"
  else
    command="${command} -o PasswordAuthentication=no"
  fi
  if [ -f "${SSH_IDENTITY_FILE}" ]; then
    command="${command} -o IdentityFile=\"${SSH_IDENTITY_FILE}\""
  fi
  if [ "${tunnel_type}" = "REMOTE" ]; then
    command="${command} -R ${bind_address}:${bind_port}:${service_host}:${service_port} ${ssh_host}"
  else
    command="${command} -L ${bind_address}:${bind_port}:${service_host}:${service_port} ${ssh_host}"
  fi
  echo "Opening ${tunnel_desc} (${bind_address}:${bind_port} -> ${service_host}:${service_port}[${ssh_user}@${ssh_host}:${ssh_port}])"
  if ${command}; then
    echo "${tunnel_desc} exited normally."
  else
    echo "${tunnel_desc} exited with code $?." >&2
  fi
}

# Initialize pids array
pids=()

# Look for insecure tunnel specifications and spawn them
while IFS=$'\t' read -r tunnel_name bind_port service_host service_port ; do
  bind_address=${bind_address:-$BIND_ADDRESS}
  tcp_tunnel ${tunnel_name} ${bind_address} ${bind_port} ${service_host} ${service_port} &
  pids+=($!)
done < <(env | grep -E "${TCP_TUNNEL_REGEX}" | sed -E "s/${TCP_TUNNEL_REGEX}/\1\t\2\t\3\t\4/")

# Look for secure tunnel specifications and spawn them
while IFS=$'\t' read -r tunnel_type tunnel_name bind_port service_host service_port ssh_user ssh_host ssh_port ; do
  tunnel_type=${tunnel_type%%'?'}
  tunnel_type=${tunnel_type%%'_'}
  ssh_user=${ssh_user%%'?'}
  ssh_user=${ssh_user%%'@'}
  ssh_port=${ssh_port##':'}
  ssh_port=${ssh_port%%'?'}
  tunnel_type=${tunnel_type:-LOCAL}
  bind_address=${bind_address:-$BIND_ADDRESS}
  ssh_user=${ssh_user:-$SSH_USER}
  ssh_port=${ssh_port:-$SSH_PORT}
  ssh_tunnel ${tunnel_type} ${tunnel_name} ${bind_address} ${bind_port} ${service_host} ${service_port} ${ssh_user} ${ssh_host} ${ssh_port} &
  pids+=($!)
done < <(env | grep -E ${SSH_TUNNEL_REGEX} | sed -E "s/^${SSH_TUNNEL_REGEX}/\1?\t\2\t\3\t\4\t\5\t\6?\t\7\t\8?/")

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
      echo >&2 "Tunnel process ${pid} not running... exiting"
      exit 1;
    fi
  done
  sleep 1
done
