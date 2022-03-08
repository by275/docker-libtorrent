FROM ubuntu:20.04 AS ubuntu
# 
# TEST
# 
FROM ubuntu AS test

ARG LIBTORRENT_VER
ARG TARGETARCH
ARG DEBIAN_FRONTEND="noninteractive"

COPY build/${TARGETARCH}/usr/ /usr/

RUN \
    echo "**** install runtime packages ****" && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        python3-minimal

RUN \
    BUILD_VER=$(python3 -c 'import libtorrent as lt; print(lt.version)') && \
    if [ $LIBTORRENT_VER = ${BUILD_VER%.*} ]; then \
        echo "Successfully built with version: ${BUILD_VER}"; \
    else \
        echo "Something went wrong: ${BUILD_VER}"; \
        exit 1; \
    fi

# 
# RELEASE
# 
FROM ubuntu
LABEL maintainer="by275"
LABEL org.opencontainers.image.source https://github.com/by275/docker-libtorrent
ARG TARGETARCH
COPY build/${TARGETARCH}/usr/ /libtorrent-build/usr/
