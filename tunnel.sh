#!/bin/sh
set -e

# Load environment variables
SSH_SERVER_CHECK_INTERVAL=${SSH_SERVER_CHECK_INTERVAL:-30}

# Look for insecure tunnel specifications and spawn them
env | grep -E '^TCP_TUNNEL_[A-Z]+_([0-9]+)=' | sed -E 's/^TCP_TUNNEL_[A-Z]+_([0-9]+)=(.+):([0-9]+)/\1 \2 \3/' | while read -r local_port remote_host remote_port ; do
  echo "Opening insecure tunnel *:$local_port -> $remote_host:$remote_port"
  /usr/bin/socat TCP4-LISTEN:$local_port,fork,reuseaddr TCP4:$remote_host:$remote_port &
  pids="$pids $!"
done

# Look for secure tunnel specifications and spawn them
env | grep -E '^SSH_TUNNEL_[A-Z]+_([0-9]+)=' | sed -E 's/^SSH_TUNNEL_[A-Z]+_([0-9]+)=(.+):(.+)@(.+):([0-9]+)/\1 \2 \3 \4 \5/' | while read -r local_port user credentials remote_host remote_port ; do

  ssh_command="/usr/bin/ssh -v -T -N -o StrictHostKeyChecking=false -o ServerAliveInterval=${SSH_SERVER_CHECK_INTERVAL}"
  ssh_command="$ssh_command -o User=$user"
  if [ -f "$credentials" ]; then
    ssh_command="$ssh_command -i \"$credentials\""
  else
    ssh_command="sshpass -p \"$credentials\" $ssh_command"
  fi
  ssh_command="$ssh_command -L *:$local_port:$remote_host:$remote_port $remote_host"
  $ssh_command &
  pids="$pids $!"

done

# Wait for all spawned processes to complete
wait $pids
