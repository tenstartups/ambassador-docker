#
# Docker ambassador pattern linking docker image
#
# http://github.com/tenstartups/ambassador-docker
#

FROM alpine:latest

MAINTAINER Marc Lennox <marc.lennox@gmail.com>

# Set environment variables.
ENV \
  TERM=xterm-color \
  ETCD_ENDPOINT=

# Install packages.
RUN \
  apk --update add bash build-base nano openssh socat sshpass wget && \
  rm /var/cache/apk/*

# Compile autossh from source.
RUN \
  cd /tmp && \
  wget http://www.harding.motd.ca/autossh/autossh-1.4e.tgz && \
  tar -xzf autossh-*.tgz && \
  cd autossh-* && \
  ./configure && \
  make && \
  make install && \
  cd .. && \
  rm -rf autossh-*

# Install etcdctl from repository.
RUN \
  cd /tmp && \
  wget --no-check-certificate https://github.com/coreos/etcd/releases/download/v2.0.13/etcd-v2.0.13-linux-amd64.tar.gz && \
  tar zxvf etcd-*-linux-amd64.tar.gz && \
  cp etcd-*-linux-amd64/etcdctl /usr/local/bin/etcdctl && \
  rm -rf etcd-*-linux-amd64 && \
  chmod +x /usr/local/bin/etcdctl

# Define working directory.
WORKDIR /root

# Add files to the container.
COPY entrypoint.sh /entrypoint
COPY tunnel.sh /usr/local/bin/tunnel
COPY sshd.sh /usr/local/bin/sshd

# Set the entrypoint script.
ENTRYPOINT ["/entrypoint"]

# Expose ports.
EXPOSE 22
