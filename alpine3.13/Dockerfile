FROM alpine:3.13 AS alpine
FROM alpine AS build-base

ARG LIBTORRENT_VER

RUN \
    echo "**** install build-deps ****" && \
    apk add --no-cache --update \
        build-base \
        boost-dev \
        cmake \
        git \
        openssl-dev \
        `# python-deps` \
        boost-python3 py3-setuptools python3-dev

RUN \
    echo "**** clone source ****" && \
    GIT_SSL_NO_VERIFY=0 git clone --recurse-submodules https://github.com/arvidn/libtorrent.git /tmp/libtorrent -b "v${LIBTORRENT_VER}" --depth 1

RUN \
    echo "**** build libtorrent ****" && \
    PY_VER=$(python3 -c 'import sys; print(".".join([str(x) for x in sys.version_info[:2]]))') && \
    mkdir /tmp/libtorrent/_build -p && \
    cd /tmp/libtorrent/_build && \
    cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="/usr" \
        -DCMAKE_INSTALL_LIBDIR="lib" \
        -Dpython-bindings=ON \
        -Dboost-python-module-name="python${PY_VER//./}" \
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

ARG LIBTORRENT_VER

COPY --from=build-base /libtorrent-build/usr/ /usr/

RUN \
    echo "**** install runtime packages ****" && \
    apk add --no-cache \
        libstdc++ \
        boost-system \
        boost-python3 \
        python3

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
FROM alpine
LABEL maintainer="wiserain"
LABEL org.opencontainers.image.source https://github.com/wiserain/docker-libtorrent
COPY --from=build-base /libtorrent-build/usr/ /libtorrent-build/usr/
