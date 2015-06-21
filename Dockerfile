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
CMD	socat TCP4-LISTEN:${TCP_LISTEN_PORT},fork,reuseaddr TCP4:${TCP_TARGET_HOST}:${TCP_TARGET_PORT}
