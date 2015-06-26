#! /bin/bash
set -u

command=$@
interval=1

is_running() { (kill -0 ${1:?is_running: missing process ID}) 2>& -; }

$command & pid=$! t0=$SECONDS
while is_running $pid; do sleep $interval; done

main
