#
# Docker ambassador pattern linking docker image
#
# http://github.com/tenstartups/ambassador-docker
#

FROM gliderlabs/alpine:latest

MAINTAINER Marc Lennox <marc.lennox@gmail.com>

# Set environment variables.
ENV \
  TERM=xterm-color \
  HOME=/home/docker

# Install socat
RUN apk --update add bash nano openssh socat sshpass

# Allow root login for sshd
RUN sed -i 's/#PermitRootLogin without-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Define working directory.
WORKDIR /home/docker

# Add files to the container.
ADD . /home/docker

# Copy scripts and configuration into place.
RUN \
  find ./script -regex '^.*\.sh\s*$' -exec bash -c 'f=`basename "{}"`; mv -v "{}" "/usr/local/bin/${f%.*}"' \; && \
  rm -rf ./script

# Set the entrypoint script.
ENTRYPOINT ["./entrypoint"]
