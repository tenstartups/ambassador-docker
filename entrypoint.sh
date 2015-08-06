#!/bin/bash
set -e

# Set environment variables
ETCD_ENVIRONMENT_VARIABLE_REGEX="^\s*ETCDENV_([^=]+)=(.+)\s*$"

# Lookup set environment variables from etcd
if ! [ -z "${ETCDCTL_PEERS}" ]; then

  # Export environment variables from etcd keys
  temp_env_file="$(mktemp)"
  chmod +x "${temp_env_file}"
  while IFS=$'\t' read -r env_name etcd_key ; do
    env_value=$(etcdctl get "${etcd_key}" 2>/dev/null || true)
    if [ -z "${env_value}" ]; then
      echo >&2 "Unable to get ${etcd_key} from etcd peers ${ETCDCTL_PEERS}."
    else
      echo "export ${env_name}=\"${env_value}\"" >> "${temp_env_file}"
    fi
  done < <(env | grep -E "${ETCD_ENVIRONMENT_VARIABLE_REGEX}" | sort | sed -E "s/${ETCD_ENVIRONMENT_VARIABLE_REGEX}/\1\t\2/")
  source "${temp_env_file}"
  rm -f "${temp_env_file}"

fi

# Look for known command aliases
case "$1" in
  "client" ) shift ; command="/usr/local/bin/tunnel" ;;
  "server" ) shift ; command="/usr/local/bin/sshd" ;;
  * )        command="$@";;
esac

exec ${command}
