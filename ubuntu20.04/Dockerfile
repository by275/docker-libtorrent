FROM ubuntu:20.04 AS ubuntu
FROM ubuntu AS build-base

ARG LIBTORRENT_VER
ARG TARGETARCH
ARG DEBIAN_FRONTEND="noninteractive"

RUN \
    echo "**** install build-deps ****" && \
    apt-get update && \
    apt-get install -yq \
        build-essential \
        git \
        libboost-chrono-dev \
        libboost-python-dev \
        libboost-random-dev \
        libboost-system-dev \
        libboost-tools-dev \
        libssl-dev \
        `# python-deps` \
        python3-setuptools python3-all-dev

RUN \
    echo "**** clone source ****" && \
    GIT_SSL_NO_VERIFY=0 git clone --recurse-submodules https://github.com/arvidn/libtorrent.git /tmp/libtorrent -b "v${LIBTORRENT_VER}" --depth 1

RUN \
    echo "**** build libtorrent-rasterbar ****" && \
    BUILD_CONFIG="release cxxstd=14 link=shared crypto=openssl warnings=off address-model=$(getconf LONG_BIT) toolset=gcc -j$(nproc)" && \
    cd /tmp/libtorrent && \
    BOOST_ROOT="" b2 \
        ${BUILD_CONFIG}

RUN \
    echo "**** prepare python envs ****" && \
    PY_VER=$(python3 -c 'import sys; print(".".join([str(x) for x in sys.version_info[:2]]))') && \
    _PY_VER="$(echo "${PY_VER}" | sed 's/\.//g')" && \
    ABIFLAGS=$(python3 -c 'import sys; print(sys.abiflags)') && \
    BOOST_PYTHON_NAME="libboost_python38" && \
    if [ ! -f "/usr/lib/${BOOST_PYTHON_NAME}.so" ]; then \
        ln -s /usr/lib/libboost_python${_PY_VER}.so "/usr/lib/${BOOST_PYTHON_NAME}.so"; \
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
    mkdir -p /libtorrent-build${PY_PKG_DIR} /libtorrent-build/usr/lib && \
    mv /tmp/libtorrent/bindings/python/*.so /libtorrent-build${PY_PKG_DIR}/ && \
    mv /tmp/libtorrent/bindings/python/dependencies/* /libtorrent-build/usr/lib/

# 
# TEST
# 
FROM ubuntu AS test

ARG LIBTORRENT_VER
ARG TARGETARCH
ARG DEBIAN_FRONTEND="noninteractive"

COPY --from=build-base /libtorrent-build/usr/ /usr/

RUN \
    echo "**** install runtime packages ****" && \
    apt-get update && \
    apt-get install -yq \
        libboost-chrono-dev \
        libboost-python-dev \
        libboost-random-dev \
        libboost-system-dev \
        libboost-tools-dev \
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
LABEL maintainer "wiserain"
COPY --from=build-base /libtorrent-build/usr/ /libtorrent-build/usr/
