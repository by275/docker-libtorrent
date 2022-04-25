FROM alpine:3.14 AS alpine

# 
# BUILD
# 
FROM alpine AS build-base

ARG LT_VER

RUN \
    echo "**** install build-deps ****" && \
    apk add --no-cache --update \
        build-base \
        `# including file fortify-headers g++ gcc libc-dev make` \
        openssl-dev \
        boost-dev \
        git \
        cmake \
        `# python-deps` \
        boost-python3 py3-setuptools python3-dev

RUN \
    echo "**** clone source ****" && \
    GIT_SSL_NO_VERIFY=0 git clone https://github.com/arvidn/libtorrent.git /tmp/libtorrent -b "v${LT_VER}" --depth 1

RUN \
    echo "**** build libtorrent ****" && \
    PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str,sys.version_info[:2])))') && \
    mkdir /tmp/libtorrent/_build -p && \
    cd /tmp/libtorrent/_build && \
    cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="/usr" \
        -DCMAKE_INSTALL_LIBDIR="lib" \
        -Dpython-bindings=ON \
        -Dboost-python-module-name="python${PYTHON_VERSION//./}" \
        "../" && \
    make VERBOSE=1 -j$(nproc) && \
    echo "**** install libtorrent ****" && \
    cd /tmp/libtorrent && \
    make -C "_build" DESTDIR=/libtorrent-build install && \
    rm -rf /libtorrent-build/usr/lib/cmake

# 
# TEST
# 
FROM alpine AS test

ARG LT_VER

COPY --from=build-base /libtorrent-build/usr/lib/ /usr/lib/
COPY --from=build-base /libtorrent-build/usr/lib/ /libtorrent-build/usr/lib/

RUN \
    echo "**** install runtime packages ****" && \
    apk add --no-cache \
        libstdc++ \
        boost-python3 \
        python3

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
FROM alpine
LABEL maintainer="by275"
LABEL org.opencontainers.image.source https://github.com/by275/docker-libtorrent
COPY --from=test /libtorrent-build/usr/lib/ /libtorrent-build/usr/lib/
