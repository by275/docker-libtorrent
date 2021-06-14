FROM ubuntu:20.04 AS ubuntu
FROM ubuntu AS build-base

ARG LIBTORRENT_VER
ARG DEBIAN_FRONTEND="noninteractive"

ENV BOOST_VER=1.71.0 \
    BOOST_BUILD_PATH=/tmp/boost

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

RUN \
    echo "**** setup cross-compile source ****" && \
    sed -i 's/^deb http/deb [arch=amd64] http/' /etc/apt/sources.list && \
    echo "deb [arch=armhf,arm64] http://ports.ubuntu.com/ focal main restricted" >> /etc/apt/sources.list.d/cross-compile-sources.list && \
    echo "deb [arch=armhf,arm64] http://ports.ubuntu.com/ focal-updates main restricted" >> /etc/apt/sources.list.d/cross-compile-sources.list && \
    echo "deb [arch=armhf,arm64] http://ports.ubuntu.com/ focal universe" >> /etc/apt/sources.list.d/cross-compile-sources.list && \
    echo "deb [arch=armhf,arm64] http://ports.ubuntu.com/ focal-updates universe" >> /etc/apt/sources.list.d/cross-compile-sources.list && \
    echo "deb [arch=armhf,arm64] http://ports.ubuntu.com/ focal multiverse" >> /etc/apt/sources.list.d/cross-compile-sources.list && \
    echo "deb [arch=armhf,arm64] http://ports.ubuntu.com/ focal-updates multiverse" >> /etc/apt/sources.list.d/cross-compile-sources.list && \
    echo "deb [arch=armhf,arm64] http://ports.ubuntu.com/ focal-backports main restricted universe multiverse" >> /etc/apt/sources.list.d/cross-compile-sources.list && \
    dpkg --add-architecture armhf && \
    dpkg --add-architecture arm64 && \
    echo "**** install build-deps ****" && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        build-essential \
        curl \
        git

RUN \
    echo "**** install boost ****" && \
    mkdir -p "${BOOST_BUILD_PATH}" && \
    cd "${BOOST_BUILD_PATH}" && \
    curl -sNLOk https://boostorg.jfrog.io/artifactory/main/release/${BOOST_VER}/source/boost_${BOOST_VER//./_}.tar.gz && \
    tar xf "boost_${BOOST_VER//./_}.tar.gz" --strip-components=1 && \
    ./bootstrap.sh && \
    ./b2 headers

RUN \
    echo "**** clone source ****" && \
    GIT_SSL_NO_VERIFY=0 git clone --recurse-submodules https://github.com/arvidn/libtorrent.git /tmp/libtorrent -b "v${LIBTORRENT_VER}" --depth 1

# 
# CROSS COMPILE
# 
FROM build-base AS build-amd64

ARG DEBIAN_FRONTEND="noninteractive"
ENV TOOLCHAIN="x86_64-linux-gnu"

RUN \
    echo "**** install build-deps ****" && \
    apt-get install -y --no-install-recommends \
        python3-all-dev \
        libssl-dev

RUN \
    echo "**** build libtorrent-rasterbar ****" && \
    BUILD_CONFIG="release cxxstd=14 link=static crypto=openssl warnings=off address-model=64 toolset=gcc target-os=linux -j$(nproc)" && \
    cd /tmp/libtorrent && \
    BOOST_ROOT="" ${BOOST_BUILD_PATH}/b2 \
        ${BUILD_CONFIG}

RUN \
    echo "**** prepare python envs ****" && \
    PY_VER=$(python3 -c 'import sys; print(".".join([str(x) for x in sys.version_info[:2]]))') && \
    ABIFLAGS=$(python3 -c 'import sys; print(sys.abiflags)') && \
    echo "using python : ${PY_VER} : /usr/bin/python${PY_VER} : /usr/include/python${PY_VER}${ABIFLAGS} : /usr/lib/python${PY_VER} : : ;" >> ~/user-config.jam && \
    echo "**** build python-bindings ****" && \
    BUILD_CONFIG="release cxxstd=14 link=shared crypto=openssl warnings=off address-model=64 toolset=gcc target-os=linux -j$(nproc)" && \
    cd /tmp/libtorrent/bindings/python && \
    BOOST_ROOT="" ${BOOST_BUILD_PATH}/b2 \
        ${BUILD_CONFIG} \
        libtorrent-link=shared boost-link=shared \
        stage_module stage_dependencies && \
    echo "**** collect build artifacts ****" && \
    PY_PKG_DIR=$(python3 -c 'import site; print(site.getsitepackages()[1])') && \
    mkdir -p /libtorrent-build${PY_PKG_DIR} && \
    mv /tmp/libtorrent/bindings/python/*.so /libtorrent-build${PY_PKG_DIR}/ && \
    LIB_DIR=/usr/lib/${TOOLCHAIN} && \
    mkdir -p /libtorrent-build${LIB_DIR} && \
    mv /tmp/libtorrent/bindings/python/dependencies/* /libtorrent-build${LIB_DIR}


FROM build-base AS build-arm64

ARG DEBIAN_FRONTEND="noninteractive"
ENV TOOLCHAIN="aarch64-linux-gnu"

RUN \
    echo "**** install build-deps ****" && \
    apt-get install -y --no-install-recommends \
        crossbuild-essential-arm64 \
        python3-all-dev:arm64 \
        libssl-dev:arm64

RUN \
    echo "**** build libtorrent-rasterbar ****" && \
    BUILD_CONFIG="release cxxstd=14 link=static crypto=openssl warnings=off address-model=64 toolset=gcc-arm target-os=linux -j$(nproc)" && \
    echo "using gcc : arm : ${TOOLCHAIN}-g++ ;" > ~/user-config.jam && \
    cd /tmp/libtorrent && \
    BOOST_ROOT="" ${BOOST_BUILD_PATH}/b2 \
        ${BUILD_CONFIG}

RUN \
    echo "**** prepare python envs ****" && \
    PY_VER=$(python3 -c 'import sys; print(".".join([str(x) for x in sys.version_info[:2]]))') && \
    ABIFLAGS=$(python3 -c 'import sys; print(sys.abiflags)') && \
    echo "using python : ${PY_VER} : /usr/bin/python${PY_VER} : /usr/include/python${PY_VER}${ABIFLAGS} : /usr/lib/python${PY_VER} : : ;" >> ~/user-config.jam && \
    echo "**** build python-bindings ****" && \
    BUILD_CONFIG="release cxxstd=14 link=shared crypto=openssl warnings=off address-model=64 toolset=gcc-arm target-os=linux -j$(nproc)" && \
    cd /tmp/libtorrent/bindings/python && \
    BOOST_ROOT="" ${BOOST_BUILD_PATH}/b2 \
        ${BUILD_CONFIG} \
        libtorrent-link=shared boost-link=shared \
        stage_module stage_dependencies && \
    echo "**** collect build artifacts ****" && \
    PY_PKG_DIR=$(python3 -c 'import site; print(site.getsitepackages()[1])') && \
    mkdir -p /libtorrent-build${PY_PKG_DIR} && \
    mv /tmp/libtorrent/bindings/python/*.so /libtorrent-build${PY_PKG_DIR}/ && \
    LIB_DIR=/usr/lib/${TOOLCHAIN} && \
    mkdir -p /libtorrent-build${LIB_DIR} && \
    mv /tmp/libtorrent/bindings/python/dependencies/* /libtorrent-build${LIB_DIR}


FROM build-base AS build-arm

ARG DEBIAN_FRONTEND="noninteractive"
ENV TOOLCHAIN="arm-linux-gnueabihf"

RUN \
    echo "**** install build-deps ****" && \
    apt-get install -y --no-install-recommends \
        crossbuild-essential-armhf \
        python3-all-dev:armhf \
        libssl-dev:armhf

RUN \
    echo "**** build libtorrent-rasterbar ****" && \
    BUILD_CONFIG="release cxxstd=14 link=static crypto=openssl warnings=off address-model=32 toolset=gcc-arm target-os=linux -j$(nproc)" && \
    echo "using gcc : arm : ${TOOLCHAIN}-g++ ;" > ~/user-config.jam && \
    cd /tmp/libtorrent && \
    BOOST_ROOT="" ${BOOST_BUILD_PATH}/b2 \
        ${BUILD_CONFIG}

RUN \
    echo "**** prepare python envs ****" && \
    PY_VER=$(python3 -c 'import sys; print(".".join([str(x) for x in sys.version_info[:2]]))') && \
    ABIFLAGS=$(python3 -c 'import sys; print(sys.abiflags)') && \
    echo "using python : ${PY_VER} : /usr/bin/python${PY_VER} : /usr/include/python${PY_VER}${ABIFLAGS} : /usr/lib/python${PY_VER} : : ;" >> ~/user-config.jam && \
    echo "**** build python-bindings ****" && \
    BUILD_CONFIG="release cxxstd=14 link=shared crypto=openssl warnings=off address-model=32 toolset=gcc-arm target-os=linux -j$(nproc)" && \
    cd /tmp/libtorrent/bindings/python && \
    BOOST_ROOT="" ${BOOST_BUILD_PATH}/b2 \
        ${BUILD_CONFIG} \
        libtorrent-link=shared boost-link=shared \
        stage_module stage_dependencies && \
    echo "**** collect build artifacts ****" && \
    PY_PKG_DIR=$(python3 -c 'import site; print(site.getsitepackages()[1])') && \
    mkdir -p /libtorrent-build${PY_PKG_DIR} && \
    mv /tmp/libtorrent/bindings/python/*.so /libtorrent-build${PY_PKG_DIR}/ && \
    LIB_DIR=/usr/lib/${TOOLCHAIN} && \
    mkdir -p /libtorrent-build${LIB_DIR} && \
    mv /tmp/libtorrent/bindings/python/dependencies/* /libtorrent-build${LIB_DIR}

# 
# RELEASE
# 
FROM ubuntu
COPY --from=build-amd64 /libtorrent-build/ /lt-build/amd64/
COPY --from=build-arm64 /libtorrent-build/ /lt-build/arm64/
COPY --from=build-arm /libtorrent-build/ /lt-build/arm/
