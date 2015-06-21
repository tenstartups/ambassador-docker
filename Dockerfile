#
# Docker ambassador pattern linking docker image
#
# http://github.com/tenstartups/ambassador-docker
#

FROM gliderlabs/alpine:latest

MAINTAINER Marc Lennox <marc.lennox@gmail.com>

# Install socat
RUN apk --update add socat

# Define command
CMD	env | grep _TCP= | sed 's/.*_PORT_\([0-9]*\)_TCP=tcp:\/\/\(.*\):\(.*\)/socat TCP4-LISTEN:\1,fork,reuseaddr TCP4:\2:\3 \&/' | sh && sleep 3153600000
