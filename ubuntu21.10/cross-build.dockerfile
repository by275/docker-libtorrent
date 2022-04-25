FROM ubuntu:21.10 AS ubuntu

# 
# BUILD
# 
FROM ubuntu AS build-base

ARG LT_VER
ARG CODENAME=impish
ARG DEBIAN_FRONTEND="noninteractive"

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

RUN \
    echo "**** setup cross-compile source ****" && \
    sed -i 's/^deb http/deb [arch=amd64] http/' /etc/apt/sources.list && \
    echo "deb [arch=armhf,arm64] http://ports.ubuntu.com/ ${CODENAME} main restricted" >> /etc/apt/sources.list.d/cross-compile-sources.list && \
    echo "deb [arch=armhf,arm64] http://ports.ubuntu.com/ ${CODENAME}-updates main restricted" >> /etc/apt/sources.list.d/cross-compile-sources.list && \
    echo "deb [arch=armhf,arm64] http://ports.ubuntu.com/ ${CODENAME} universe" >> /etc/apt/sources.list.d/cross-compile-sources.list && \
    echo "deb [arch=armhf,arm64] http://ports.ubuntu.com/ ${CODENAME}-updates universe" >> /etc/apt/sources.list.d/cross-compile-sources.list && \
    echo "deb [arch=armhf,arm64] http://ports.ubuntu.com/ ${CODENAME} multiverse" >> /etc/apt/sources.list.d/cross-compile-sources.list && \
    echo "deb [arch=armhf,arm64] http://ports.ubuntu.com/ ${CODENAME}-updates multiverse" >> /etc/apt/sources.list.d/cross-compile-sources.list && \
    echo "deb [arch=armhf,arm64] http://ports.ubuntu.com/ ${CODENAME}-backports main restricted universe multiverse" >> /etc/apt/sources.list.d/cross-compile-sources.list && \
    dpkg --add-architecture armhf && \
    dpkg --add-architecture arm64 && \
    echo "**** install build-deps ****" && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        curl \
        git \
        libboost-tools-dev

RUN \
    echo "**** clone source ****" && \
    GIT_SSL_NO_VERIFY=0 git clone --recurse-submodules https://github.com/arvidn/libtorrent.git /tmp/libtorrent -b "v${LT_VER}" --depth 1

# 
# CROSS COMPILE
# 
FROM build-base AS build-amd64

ARG DEBIAN_FRONTEND="noninteractive"
ENV TOOLCHAIN=x86_64-linux-gnu \
    ARCH=amd64 \
    BUILD_CONFIG="address-model=64 toolset=gcc-amd64"

RUN \
    echo "**** install build-deps ****" && \
    apt-get install -y --no-install-recommends \
        crossbuild-essential-${ARCH} \
        python3-all-dev:${ARCH} \
        libboost-dev:${ARCH} \
        libboost-python-dev:${ARCH} \
        libboost-system-dev:${ARCH} \
        libssl-dev:${ARCH}

RUN \
    echo "**** build libtorrent-rasterbar ****" && \
    echo "using gcc : ${ARCH} : ${TOOLCHAIN}-g++ ;" >> ~/user-config.jam && \
    cd /tmp/libtorrent && \
    BOOST_ROOT="" /usr/bin/b2 -j$(nproc) release cxxstd=14 crypto=openssl warnings=off target-os=linux \
        ${BUILD_CONFIG} link=shared

RUN \
    echo "**** prepare python envs ****" && \
    PY_VER=$(python3 -c 'import sys; print(".".join(map(str,sys.version_info[:2])))') && \
    ABIFLAGS=$(python3 -c 'import sys; print(sys.abiflags)') && \
    echo "using python : ${PY_VER} : /usr/bin/python${PY_VER} : /usr/include/python${PY_VER}${ABIFLAGS} : /usr/lib/python${PY_VER} : : ;" >> ~/user-config.jam && \
    echo "**** build python-bindings ****" && \
    cd /tmp/libtorrent/bindings/python && \
    BOOST_ROOT="" /usr/bin/b2 -j$(nproc) release cxxstd=14 crypto=openssl warnings=off target-os=linux \
        ${BUILD_CONFIG} link=shared libtorrent-link=shared boost-link=shared \
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
ENV TOOLCHAIN=aarch64-linux-gnu \
    ARCH=arm64 \
    BUILD_CONFIG="address-model=64 toolset=gcc-arm64"

RUN \
    echo "**** install build-deps ****" && \
    apt-get install -y --no-install-recommends \
        crossbuild-essential-${ARCH} \
        python3-all-dev:${ARCH} \
        libboost-dev:${ARCH} \
        libboost-python-dev:${ARCH} \
        libboost-system-dev:${ARCH} \
        libssl-dev:${ARCH}

RUN \
    echo "**** build libtorrent-rasterbar ****" && \
    echo "using gcc : ${ARCH} : ${TOOLCHAIN}-g++ ;" >> ~/user-config.jam && \
    cd /tmp/libtorrent && \
    BOOST_ROOT="" /usr/bin/b2 -j$(nproc) release cxxstd=14 crypto=openssl warnings=off target-os=linux \
        ${BUILD_CONFIG} link=shared

RUN \
    echo "**** prepare python envs ****" && \
    PY_VER=$(python3 -c 'import sys; print(".".join(map(str,sys.version_info[:2])))') && \
    ABIFLAGS=$(python3 -c 'import sys; print(sys.abiflags)') && \
    echo "using python : ${PY_VER} : /usr/bin/python${PY_VER} : /usr/include/python${PY_VER}${ABIFLAGS} : /usr/lib/python${PY_VER} : : ;" >> ~/user-config.jam && \
    echo "**** build python-bindings ****" && \
    cd /tmp/libtorrent/bindings/python && \
    BOOST_ROOT="" /usr/bin/b2 -j$(nproc) release cxxstd=14 crypto=openssl warnings=off target-os=linux \
        ${BUILD_CONFIG} link=shared libtorrent-link=shared boost-link=shared \
        stage_module stage_dependencies && \
    echo "**** collect build artifacts ****" && \
    PY_PKG_DIR=$(python3 -c 'import site; print(site.getsitepackages()[1])') && \
    mkdir -p /libtorrent-build${PY_PKG_DIR} && \
    mv /tmp/libtorrent/bindings/python/*.so /libtorrent-build${PY_PKG_DIR}/ && \
    LIB_DIR=/usr/lib/${TOOLCHAIN} && \
    mkdir -p /libtorrent-build${LIB_DIR} && \
    mv /tmp/libtorrent/bindings/python/dependencies/* /libtorrent-build${LIB_DIR}


FROM build-base AS build-armhf

ARG DEBIAN_FRONTEND="noninteractive"
ENV TOOLCHAIN=arm-linux-gnueabihf \
    ARCH=armhf \
    BUILD_CONFIG="address-model=32 toolset=gcc-armhf"

RUN \
    echo "**** install build-deps ****" && \
    apt-get install -y --no-install-recommends \
        crossbuild-essential-${ARCH} \
        python3-all-dev:${ARCH} \
        libboost-dev:${ARCH} \
        libboost-python-dev:${ARCH} \
        libboost-system-dev:${ARCH} \
        libssl-dev:${ARCH}

RUN \
    echo "**** build libtorrent-rasterbar ****" && \
    echo "using gcc : ${ARCH} : ${TOOLCHAIN}-g++ ;" >> ~/user-config.jam && \
    cd /tmp/libtorrent && \
    BOOST_ROOT="" /usr/bin/b2 -j$(nproc) release cxxstd=14 crypto=openssl warnings=off target-os=linux \
        ${BUILD_CONFIG} link=shared

RUN \
    echo "**** prepare python envs ****" && \
    PY_VER=$(python3 -c 'import sys; print(".".join(map(str,sys.version_info[:2])))') && \
    ABIFLAGS=$(python3 -c 'import sys; print(sys.abiflags)') && \
    echo "using python : ${PY_VER} : /usr/bin/python${PY_VER} : /usr/include/python${PY_VER}${ABIFLAGS} : /usr/lib/python${PY_VER} : : ;" >> ~/user-config.jam && \
    echo "**** build python-bindings ****" && \
    cd /tmp/libtorrent/bindings/python && \
    BOOST_ROOT="" /usr/bin/b2 -j$(nproc) release cxxstd=14 crypto=openssl warnings=off target-os=linux \
        ${BUILD_CONFIG} link=shared libtorrent-link=shared boost-link=shared \
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
COPY --from=build-armhf /libtorrent-build/ /lt-build/arm/
