#!/bin/bash
set -e

# Set environment variables
ETCD_ENVIRONMENT_VARIABLE_REGEX="^\s*([^=]+)=etcd:\/\/([^\/:]+(:([0-9]+))?)?(\/.+)\s*$"

# Lookup set environment variables from etcd
if ! [ -z "$(env | grep -E "${ETCD_ENVIRONMENT_VARIABLE_REGEX}")" ]; then

  # Export environment variables from etcd keys
  temp_env_file="$(mktemp)"
  chmod +x "${temp_env_file}"
  while IFS=$'\t' read -r env_name etcd_endpoint etcd_key ; do
    etcd_endpoint=${etcd_endpoint%%'?'}
    etcd_endpoint=${etcd_endpoint:-$ETCD_ENDPOINT}
    etcd_endpoint=${etcd_endpoint:-127.0.0.1:2379}
    env_value=$(etcdctl --peers=${etcd_endpoint} get ${etcd_key} 2>/dev/null || true)
    if [ -z "${env_value}" ]; then
      echo >&2 "Unable to get ${etcd_key} from etcd at ${etcd_endpoint}."
      exit 1
    fi
    echo "export ${env_name}=\"${env_value}\"" >> "${temp_env_file}"
  done < <(env | grep -E "${ETCD_ENVIRONMENT_VARIABLE_REGEX}" | sort | sed -E "s/${ETCD_ENVIRONMENT_VARIABLE_REGEX}/\1\t\2?\t\5/")
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
