#! /bin/bash
set -u

# Load environment variables
TCP_TUNNEL_REGEX="^\s*TCP_TUNNEL_([A-Z]+)_([0-9]+)=(.+):([0-9]+)"
SSH_TUNNEL_REGEX="^\s*SSH_TUNNEL_([A-Z]+)_([0-9]+)=(.+):(.+)@(.+):([0-9]+):([0-9]+)"
SSH_SERVER_CHECK_INTERVAL=${SSH_SERVER_CHECK_INTERVAL:-30}

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
  ssh_port=$4
  remote_port=$5
  user=$6
  password_or_identity_file=$7
  exit_loop=0
  trap 'exit_loop=1' SIGINT SIGQUIT
  command="/usr/bin/ssh -T -N -o StrictHostKeyChecking=false -o ServerAliveInterval=${SSH_SERVER_CHECK_INTERVAL}"
  command="$command -o User=$user"
  command="$command -o Port=$ssh_port"
  if [ -f "$password_or_identity_file" ]; then
    command="$command -o PasswordAuthentication=false -o IdentityFile=\"$password_or_identity_file\""
    echo "Opening $tunnel_name SSH tunnel (*:$local_port -> $remote_host:$remote_port) with user $user and identity $password_or_identity_file"
  else
    command="/usr/bin/sshpass -p \"$password_or_identity_file\" $command"
    echo "Opening $tunnel_name SSH tunnel (*:$local_port -> $remote_host:$remote_port) with user $user and password"
  fi
  command="$command -L *:$local_port:$remote_host:$remote_port $remote_host"
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
