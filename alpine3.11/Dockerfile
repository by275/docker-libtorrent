FROM alpine:3.11 AS alpine
FROM alpine AS build-base

ARG LIBTORRENT_VER

RUN \
    echo "**** install build-deps ****" && \
    apk add --no-cache --update \
        build-base \
        `# including file fortify-headers g++ gcc libc-dev make` \
        openssl-dev \
        boost-dev \
        git \
        boost-build \
        `# python-deps` \
        boost-python3 py3-setuptools python3-dev

RUN \
    echo "**** clone source ****" && \
    GIT_SSL_NO_VERIFY=0 git clone https://github.com/arvidn/libtorrent.git /tmp/libtorrent -b "v${LIBTORRENT_VER}" --depth 1

RUN \
    echo "**** build libtorrent-rasterbar ****" && \
    BUILD_CONFIG="release cxxstd=14 link=shared crypto=openssl warnings=off address-model=$(getconf LONG_BIT) toolset=gcc -j$(nproc)" && \
    cd /tmp/libtorrent && \
    BOOST_ROOT="" b2 \
        ${BUILD_CONFIG}

RUN \
    echo "**** prepare python envs ****" && \
    PY_VER=$(python3 -c 'import sys; print(".".join([str(x) for x in sys.version_info[:2]]))') && \
    ABIFLAGS=$(python3 -c 'import sys; print(sys.abiflags)') && \
    BOOST_PYTHON_NAME="libboost_python38" && \
    if [ ! -f "/usr/lib/${BOOST_PYTHON_NAME}.so" ]; then \
        ln -s /usr/lib/libboost_python${PY_VER//./}.so "/usr/lib/${BOOST_PYTHON_NAME}.so"; \
    fi && \
    echo "using python : ${PY_VER} : /usr/bin/python${PY_VER} : /usr/include/python${PY_VER}${ABIFLAGS} : /usr/lib/python${PY_VER} : : ;" > /root/user-config.jam && \
    echo "**** build python-bindings ****" && \
    BUILD_CONFIG="release cxxstd=14 link=shared crypto=openssl warnings=off address-model=$(getconf LONG_BIT) toolset=gcc -j$(nproc)" && \
    cd /tmp/libtorrent/bindings/python && \
    BOOST_ROOT="" b2 \
        ${BUILD_CONFIG} \
        libtorrent-link=shared boost-link=shared \
        stage_module stage_dependencies && \
    echo "**** collect build artifacts ****" && \
    PY_PKG_DIR=$(python3 -c 'import site; print(site.getsitepackages()[0])') && \
    mkdir -p /libtorrent-build${PY_PKG_DIR} && \
    mv /tmp/libtorrent/bindings/python/*.so /libtorrent-build${PY_PKG_DIR}/ && \
    mv /tmp/libtorrent/bindings/python/dependencies/* /libtorrent-build/usr/lib/

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
COPY --from=build-base /libtorrent-build/usr/lib/ /libtorrent-build/usr/lib/
