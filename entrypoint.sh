#!/bin/bash
set -e

# Set environment variables
ETCD_ENVIRONMENT_VARIABLE_REGEX="^\s*ETCD2ENV_([_A-Z0-9]+)=(.+)\s*$"

if ! [ -z "${ETCD_ENDPOINT}" ]; then

  # Wait for etcd service to respond before proceeding
  until etcdctl --peers "${ETCD_ENDPOINT}" ls --recursive >/dev/null 2>&1; do
    echo "Waiting for etcd to start responding..."
    failures=$((failures+1))
    if [ ${failures} -gt 20 ]; then
      echo >&2 "Timed-out waiting for etcd to start responding."
      exit 1
    fi
    sleep 5
  done

  # Export environment variables from etcd keys
  temp_env_file="$(mktemp)"
  chmod +x "${temp_env_file}"
  while read -r env_name etcd_variable ; do
    env_value=$(etcdctl --peers "${ETCD_ENDPOINT}" get "${etcd_variable}")
    if [ -z "${env_value}" ]; then
      echo >&2 "Unable to load ${etcd_variable} variable from etcd."
      exit 1
    fi
    echo "export ${env_name}=\"${env_value}\"" >> "${temp_env_file}"
  done < <(env | grep -E "${ETCD_ENVIRONMENT_VARIABLE_REGEX}" | sed -E "s/${ETCD_ENVIRONMENT_VARIABLE_REGEX}/\1 \2/" | sort | uniq)
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
