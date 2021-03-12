FROM ubuntu:18.04 AS ubuntu
FROM ubuntu AS builder

ARG TARGETARCH
ARG DEBIAN_FRONTEND="noninteractive"
ENV CMAKE_VER="3.17.5"

RUN \
    echo "**** install cmake v${CMAKE_VER} ****" && \
    apt-get update && \
    apt-get install -yqq --no-install-recommends \
        build-essential \
        liblzma-dev \
        libbz2-dev \
        libssl-dev \
        librhash-dev \
        libexpat1-dev \
        zlib1g-dev \
        libcurl4-openssl-dev \
        libarchive-dev \
        libjsoncpp-dev \
        libuv1-dev \
        wget && \
    if [ $TARGETARCH = "arm" ]; then \
        export CFLAGS="-D_FILE_OFFSET_BITS=64" && \
        export CXXFLAGS="-D_FILE_OFFSET_BITS=64"; \
    fi && \
    cd $(mktemp -d) && \
    wget https://cmake.org/files/v${CMAKE_VER%.*}/cmake-${CMAKE_VER}.tar.gz --no-check-certificate && \
    tar -xzf cmake-${CMAKE_VER}.tar.gz --strip-components=1 && \
    ./bootstrap \
        --prefix=/usr \
        --parallel=$(nproc) \
        --system-libs \
        --no-system-libarchive \
        -- \
        -DCMAKE_BUILD_TYPE:STRING=Release && \
    make -j$(nproc) && \
    make DESTDIR=/tmp/cmake-build install

# 
# RELEASE
# 
FROM ubuntu
LABEL maintainer="wiserain"
LABEL org.opencontainers.image.source https://github.com/wiserain/docker-libtorrent
COPY --from=builder /tmp/cmake-build/usr/ /usr/
