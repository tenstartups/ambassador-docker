Docker Ambassador with SSH Encrypted Tunnel Support
==

This is a concrete implementation of the Docker ambassador linking pattern (https://docs.docker.com/articles/ambassador_pattern_linking/) with support for both TCP and SSH encrypted tunnels.

The goal for this project was to create an ambassador image that would allow for both encrypted and unencrypted tunnels between docker hosts, using already existing tools (ssh, autossh, socat) and simple environment tunnel descriptors.  The image can be launched in either server or client mode.

### Ambassador server

Server mode runs an ssh daemon and is designed to be linked with other docker containers, allowing remote docker containers to link seamlessly to services on the same host as the server ambassador.  As an example, the server ambassador could be launched with the following Docker command.

```sh
/usr/bin/docker run \
  -p 2222:22 \
  -v /host/path/to/keys:/keys \
  -e SSH_HOST_KEY_FILE=/keys/ssh-server-key.pem \
  -e SSH_AUTHORIZED_KEYS_FILE=/keys/ssh-authorized-keys.pub \
  --link service1:service1 \
  --link service2:service2 \
  --link service3:service3 \
  --name ambassador-server \
  tenstartups/ambassador:latest \
  server
```

As shown in the example, you need to provide the container with access to a file containing a list of authorized public keys, matching the client private keys that will be used to connect from the client ambassador.

### Ambassador client

```sh
/usr/bin/docker run \
  -p 172.:11211:11211 \
  -p ${DOCKER0_IP_ADDRESS}:6379:6379 \
  -p ${DOCKER0_IP_ADDRESS}:5432:5432 \
  -e TCP_TUNNEL_MEMCACHE_11211=memcache:11211 \
  -e TCP_TUNNEL_REDIS_6379=redis:6379 \
  -e TCP_TUNNEL_POSTGRESQL_5432=postgresql:5432 \
  --link memcache-server.service:memcache \
  --link redis-server.service:redis \
  --link postgresql-server.service:postgresql \
  --hostname ${DOCKER_CONTAINER_NAME}.${DOCKER_HOSTNAME_FULL} \
  --name ${DOCKER_CONTAINER_NAME} \
  ${DOCKER_IMAGE_AMBASSADOR_LOCAL} \
  client
```
