#!/bin/sh
set -e

# Extract arguments from environment
line=$(env | grep _TCP= | head | sed 's/.*_PORT_\([0-9]*\)_TCP=tcp:\/\/\(.*\):\(.*\)/echo \1 \2 \3/' | sh)

# Return if no tunnel spec found
if [ -z "$line" ]; then
  echo "Tunnel specification not found in environment"
  exit 1
fi

# Extract invididual variables
TCP_LISTEN_PORT=$(echo $line | cut -d' ' -f1)
TCP_TARGET_HOST=$(echo $line | cut -d' ' -f2)
TCP_TARGET_PORT=$(echo $line | cut -d' ' -f3)

# Run socat with extracted arguments
echo "Opening tunnel tcp://localhost:${TCP_LISTEN_PORT} => tcp://${TCP_TARGET_HOST}:${TCP_TARGET_PORT}"
exec socat TCP4-LISTEN:${TCP_LISTEN_PORT},fork,reuseaddr TCP4:${TCP_TARGET_HOST}:${TCP_TARGET_PORT}
