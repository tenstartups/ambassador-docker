#
# Docker ambassador pattern linking docker image
#
# http://github.com/tenstartups/ambassador-docker
#

FROM alpine:latest

MAINTAINER Marc Lennox <marc.lennox@gmail.com>

# Set environment variables.
ENV \
  AUTOSSH_VERSION=1.4e \
  SSH_PORT=2222 \
  TERM=xterm-color

# Install packages.
RUN \
  apk --update add bash build-base nano openssh socat sshpass wget && \
  rm /var/cache/apk/*

# Compile autossh from source.
RUN \
  cd /tmp && \
  wget http://www.harding.motd.ca/autossh/autossh-${AUTOSSH_VERSION}.tgz && \
  tar -xzf autossh-*.tgz && \
  cd autossh-* && \
  ./configure && \
  make && \
  make install && \
  cd .. && \
  rm -rf autossh-*

# Define working directory.
WORKDIR /root

# Add files to the container.
COPY entrypoint.sh /entrypoint
COPY tunnel.sh /usr/local/bin/tunnel
COPY sshd.sh /usr/local/bin/sshd

# Set the entrypoint script.
ENTRYPOINT ["/entrypoint"]

# Expose ports.
EXPOSE 2222
