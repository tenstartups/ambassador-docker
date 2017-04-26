ifeq ($(DOCKER_ARCH),armhf)
	DOCKER_IMAGE_NAME := tenstartups/ambassador:armhf
else
	DOCKER_ARCH := x64
	DOCKER_IMAGE_NAME := tenstartups/ambassador:latest
endif

build: Dockerfile.$(DOCKER_ARCH)
	docker build --file Dockerfile.$(DOCKER_ARCH) --tag $(DOCKER_IMAGE_NAME) .

clean_build: Dockerfile.$(DOCKER_ARCH)
	docker build --no-cache --pull --file Dockerfile.$(DOCKER_ARCH) --tag $(DOCKER_IMAGE_NAME) .

run: build
	docker run -it --rm -e TCP_TUNNEL_MYTUNNEL_2306=testing:2307 -e TCP_TUNNEL_MYTUNNEL_2_2307=testing_2:2308 -e SSH_TUNNEL_MYTUNNEL_3_2308=test:8888[remote:345] -e SSH_REMOTE_TUNNEL_MYTUNNEL_4_2309=test:8888[remote:345] --name ambassador $(DOCKER_IMAGE_NAME) $(ARGS)

push: build
	docker push $(DOCKER_IMAGE_NAME)
