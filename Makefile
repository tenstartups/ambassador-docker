DOCKER_IMAGE_NAME := tenstartups/ambassador
UNAME_S := $(shell uname -m)
ifneq (,$(findstring arm,$(UNAME_S)))
	PLATFORM := rpi
	DOCKER_IMAGE_NAME := $(subst /,/${PLATFORM}-,${DOCKER_IMAGE_NAME})
else
	PLATFORM := x64
endif

build: Dockerfile.${PLATFORM}
	docker build --file Dockerfile.${PLATFORM} --tag ${DOCKER_IMAGE_NAME} .

clean_build: Dockerfile.${PLATFORM}
	docker build --no-cache --file Dockerfile.${PLATFORM} --tag ${DOCKER_IMAGE_NAME} .

run: build
	docker run -it --rm ${DOCKER_IMAGE_NAME} ${ARGS}

push: clean_build
	docker push ${DOCKER_IMAGE_NAME}:latest
