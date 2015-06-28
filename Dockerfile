#
# Docker ambassador pattern linking docker image
#
# http://github.com/tenstartups/ambassador-docker
#

FROM gliderlabs/alpine:latest

MAINTAINER Marc Lennox <marc.lennox@gmail.com>

# Set environment variables.
ENV \
  TERM=xterm-color

# Install socat
RUN apk --update add bash nano openssh socat sshpass

# Define working directory.
WORKDIR /root

# Add files to the container.
ADD . /root

# Copy scripts and configuration into place.
RUN \
  mkdir /root/.ssh && \
  chmod 700 /root/.ssh && \
  find ./script -regex '^.*\.sh\s*$' -exec bash -c 'f=`basename "{}"`; mv -v "{}" "/usr/local/bin/${f%.*}"' \; && \
  rm -rf ./script

# Set the entrypoint script.
ENTRYPOINT ["./entrypoint"]

# Expose ports.
EXPOSE 22
