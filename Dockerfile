#
# Docker ambassador pattern linking docker image
#
# http://github.com/tenstartups/ambassador-docker
#

FROM gliderlabs/alpine:latest

MAINTAINER Marc Lennox <marc.lennox@gmail.com>

# Install socat
RUN apk --update add bash nano openssh socat sshpass

# Add files
COPY ./run.sh /usr/local/bin/run
COPY ./tunnel.sh /usr/local/bin/tunnel

# Define command
CMD	["/usr/local/bin/tunnel"]
