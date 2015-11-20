DOCKER_IMAGE_NAME := tenstartups/ambassador
DOCKER_ARCH := $(shell uname -m)
ifneq (,$(findstring arm,$(DOCKER_ARCH)))
	DOCKER_PLATFORM := rpi
	DOCKER_IMAGE_NAME := $(subst /,/${DOCKER_PLATFORM}-,${DOCKER_IMAGE_NAME})
else
	DOCKER_PLATFORM := x64
endif

build: Dockerfile.${DOCKER_PLATFORM}
	docker build --file Dockerfile.${DOCKER_PLATFORM} --tag ${DOCKER_IMAGE_NAME} .

clean_build: Dockerfile.${DOCKER_PLATFORM}
	docker build --no-cache --file Dockerfile.${DOCKER_PLATFORM} --tag ${DOCKER_IMAGE_NAME} .

run: build
	docker run -it --rm ${DOCKER_IMAGE_NAME} ${ARGS}

push: clean_build
	docker push ${DOCKER_IMAGE_NAME}:latest
