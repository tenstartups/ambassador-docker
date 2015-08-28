#!/bin/bash
set -e

# Look for known command aliases
case "$1" in
  "client" ) shift ; exec "/usr/local/bin/tunnel" "$@" ;;
  "server" ) shift ; exec "/usr/local/bin/sshd" "$@" ;;
  * )        exec "$@" ;;
esac
