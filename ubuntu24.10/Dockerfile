FROM ubuntu:24.10 AS ubuntu

# 
# TEST
# 
FROM ubuntu AS test

ARG LT_VER
ARG TARGETARCH
ARG DEBIAN_FRONTEND="noninteractive"

COPY build/${TARGETARCH}/usr/ /usr/
COPY build/${TARGETARCH}/usr/ /libtorrent-build/usr/

RUN \
    echo "**** install runtime packages ****" && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        'libboost-python[0-9.]+$' \
        python3-minimal

RUN \
    BUILD_VER=$(python3 -c 'import libtorrent as lt; print(lt.version)') && \
    if [ $LT_VER = ${BUILD_VER%.*} ]; then \
        echo "Successfully built with version: ${BUILD_VER}"; \
    else \
        echo "Something went wrong: ${BUILD_VER}"; \
        exit 1; \
    fi

# 
# RELEASE
# 
FROM scratch
LABEL maintainer="by275"
LABEL org.opencontainers.image.source=https://github.com/by275/docker-libtorrent
COPY --from=test /libtorrent-build/usr/ /libtorrent-build/usr/
