FROM ubuntu:24.10 AS ubuntu

# 
# BUILD
# 
FROM ubuntu AS build-base

ARG LT_VER
ARG DEBIAN_FRONTEND="noninteractive"

ENV GIT_SSL_NO_VERIFY=0 \
    BOOST_ROOT=""

SHELL ["/bin/bash", "-euo", "pipefail", "-c"]

RUN \
    echo "**** setup cross-compile source ****" && \
    CODENAME=$(. /etc/os-release && echo $VERSION_CODENAME) && \
    sed -r -i '/^Arch/d;s/^URIs:/Architectures:\x20amd64\n&/g' /etc/apt/sources.list.d/ubuntu.sources && \
    echo "Types: deb" >> /etc/apt/sources.list.d/cross-compile.sources && \
    echo "Architectures: arm64 armhf" >> /etc/apt/sources.list.d/cross-compile.sources && \
    echo "URIs: http://ports.ubuntu.com/" >> /etc/apt/sources.list.d/cross-compile.sources && \
    echo "Suites: ${CODENAME} ${CODENAME}-updates ${CODENAME}-backports" >> /etc/apt/sources.list.d/cross-compile.sources && \
    echo "Components: main universe restricted multiverse" >> /etc/apt/sources.list.d/cross-compile.sources && \
    echo "Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg" >> /etc/apt/sources.list.d/cross-compile.sources && \
    dpkg --add-architecture armhf && \
    dpkg --add-architecture arm64 && \
    echo "**** install build-deps ****" && \
    apt-get update -qq && \
    apt-get install -yqq --no-install-recommends \
        curl \
        git \
        libboost-tools-dev

RUN \
    echo "**** clone source ****" && \
    git clone --recurse-submodules https://github.com/arvidn/libtorrent.git /tmp/libtorrent -b "v${LT_VER}" --depth 1

# 
# CROSS COMPILE
# 
FROM build-base AS build-amd64

ARG DEBIAN_FRONTEND="noninteractive"

ENV TOOLCHAIN=x86_64-linux-gnu \
    ARCH=amd64 \
    BUILD_DEPS=build-essential \
    BUILD_CONFIG="release cxxstd=14 crypto=openssl warnings=off toolset=gcc-amd64 address-model=64"

RUN \
    echo "**** install build-deps ****" && \
    apt-get install -yqq --no-install-recommends \
        ${BUILD_DEPS} \
        python3-all-dev:${ARCH} \
        libboost-dev:${ARCH} \
        libboost-python-dev:${ARCH} \
        libboost-system-dev:${ARCH} \
        libssl-dev:${ARCH}

RUN \
    echo "**** setup b2 user-config.jam ****" && \
    echo "using gcc : ${ARCH} : ${TOOLCHAIN}-g++ ;" >> ~/user-config.jam

# RUN \
#     echo "**** build libtorrent-rasterbar ****" && \
#     cd /tmp/libtorrent && \
#     b2 -j$(nproc) ${BUILD_CONFIG} \
#         link=shared

RUN \
    echo "**** prepare python envs ****" && \
    PY_VER=$(python3 -c 'import sys; print(".".join(map(str,sys.version_info[:2])))') && \
    ABIFLAGS=$(python3 -c 'import sys; print(sys.abiflags)') && \
    EXT_SUFFIX=$(python3 -c 'import sysconfig; print(sysconfig.get_config_var("EXT_SUFFIX"))') && \
    echo "using python : ${PY_VER} : /usr/bin/python${PY_VER} : /usr/include/python${PY_VER}${ABIFLAGS} : /usr/lib/python${PY_VER} : : ${EXT_SUFFIX%%.so} ;" >> ~/user-config.jam && \
    echo "**** build python-bindings ****" && \
    cd /tmp/libtorrent/bindings/python && \
    b2 -j$(nproc) ${BUILD_CONFIG} \
        libtorrent-link=shared \
        boost-link=shared \
        stage_module \
        stage_dependencies && \
    echo "**** collect build artifacts ****" && \
    PY_PKG_DIR=$(python3 -c 'import site; print(site.getsitepackages()[1])') && \
    mkdir -p /libtorrent-build${PY_PKG_DIR} && \
    mv /tmp/libtorrent/bindings/python/*.so /libtorrent-build${PY_PKG_DIR}/ && \
    LIBDIR=/usr/lib/${TOOLCHAIN} && \
    mkdir -p /libtorrent-build${LIBDIR} && \
    mv /tmp/libtorrent/bindings/python/dependencies/* /libtorrent-build${LIBDIR}


FROM build-base AS build-arm64

ARG DEBIAN_FRONTEND="noninteractive"

ENV TOOLCHAIN=aarch64-linux-gnu \
    ARCH=arm64 \
    BUILD_DEPS=crossbuild-essential-arm64 \
    BUILD_CONFIG="release cxxstd=14 crypto=openssl warnings=off toolset=gcc-arm64 address-model=64"

RUN \
    echo "**** install build-deps ****" && \
    apt-get install -yqq --no-install-recommends \
        ${BUILD_DEPS} \
        python3-all-dev:${ARCH} \
        libboost-dev:${ARCH} \
        libboost-python-dev:${ARCH} \
        libboost-system-dev:${ARCH} \
        libssl-dev:${ARCH}

RUN \
    echo "**** setup b2 user-config.jam ****" && \
    echo "using gcc : ${ARCH} : ${TOOLCHAIN}-g++ ;" >> ~/user-config.jam

# RUN \
#     echo "**** build libtorrent-rasterbar ****" && \
#     cd /tmp/libtorrent && \
#     b2 -j$(nproc) ${BUILD_CONFIG} \
#         link=shared

RUN \
    echo "**** prepare python envs ****" && \
    PY_VER=$(python3 -c 'import sys; print(".".join(map(str,sys.version_info[:2])))') && \
    ABIFLAGS=$(python3 -c 'import sys; print(sys.abiflags)') && \
    EXT_SUFFIX=$(python3 -c 'import sysconfig; print(sysconfig.get_config_var("EXT_SUFFIX"))') && \
    echo "using python : ${PY_VER} : /usr/bin/python${PY_VER} : /usr/include/python${PY_VER}${ABIFLAGS} : /usr/lib/python${PY_VER} : : ${EXT_SUFFIX%%.so} ;" >> ~/user-config.jam && \
    echo "**** build python-bindings ****" && \
    cd /tmp/libtorrent/bindings/python && \
    b2 -j$(nproc) ${BUILD_CONFIG} \
        libtorrent-link=shared \
        boost-link=shared \
        stage_module \
        stage_dependencies && \
    echo "**** collect build artifacts ****" && \
    PY_PKG_DIR=$(python3 -c 'import site; print(site.getsitepackages()[1])') && \
    mkdir -p /libtorrent-build${PY_PKG_DIR} && \
    mv /tmp/libtorrent/bindings/python/*.so /libtorrent-build${PY_PKG_DIR}/ && \
    LIBDIR=/usr/lib/${TOOLCHAIN} && \
    mkdir -p /libtorrent-build${LIBDIR} && \
    mv /tmp/libtorrent/bindings/python/dependencies/* /libtorrent-build${LIBDIR}


FROM build-base AS build-armhf

ARG DEBIAN_FRONTEND="noninteractive"

ENV TOOLCHAIN=arm-linux-gnueabihf \
    ARCH=armhf \
    BUILD_DEPS=crossbuild-essential-armhf \
    BUILD_CONFIG="release cxxstd=14 crypto=openssl warnings=off toolset=gcc-armhf address-model=32"

RUN \
    echo "**** install build-deps ****" && \
    apt-get install -yqq --no-install-recommends \
        ${BUILD_DEPS} \
        python3-all-dev:${ARCH} \
        libboost-dev:${ARCH} \
        libboost-python-dev:${ARCH} \
        libboost-system-dev:${ARCH} \
        libssl-dev:${ARCH}

RUN \
    echo "**** setup b2 user-config.jam ****" && \
    echo "using gcc : ${ARCH} : ${TOOLCHAIN}-g++ ;" >> ~/user-config.jam

# RUN \
#     echo "**** build libtorrent-rasterbar ****" && \
#     cd /tmp/libtorrent && \
#     b2 -j$(nproc) ${BUILD_CONFIG} \
#         link=shared

RUN \
    echo "**** prepare python envs ****" && \
    PY_VER=$(python3 -c 'import sys; print(".".join(map(str,sys.version_info[:2])))') && \
    ABIFLAGS=$(python3 -c 'import sys; print(sys.abiflags)') && \
    EXT_SUFFIX=$(python3 -c 'import sysconfig; print(sysconfig.get_config_var("EXT_SUFFIX"))') && \
    echo "using python : ${PY_VER} : /usr/bin/python${PY_VER} : /usr/include/python${PY_VER}${ABIFLAGS} : /usr/lib/python${PY_VER} : : ${EXT_SUFFIX%%.so} ;" >> ~/user-config.jam && \
    echo "**** build python-bindings ****" && \
    cd /tmp/libtorrent/bindings/python && \
    b2 -j$(nproc) ${BUILD_CONFIG} \
        libtorrent-link=shared \
        boost-link=shared \
        stage_module \
        stage_dependencies && \
    echo "**** collect build artifacts ****" && \
    PY_PKG_DIR=$(python3 -c 'import site; print(site.getsitepackages()[1])') && \
    mkdir -p /libtorrent-build${PY_PKG_DIR} && \
    mv /tmp/libtorrent/bindings/python/*.so /libtorrent-build${PY_PKG_DIR}/ && \
    LIBDIR=/usr/lib/${TOOLCHAIN} && \
    mkdir -p /libtorrent-build${LIBDIR} && \
    mv /tmp/libtorrent/bindings/python/dependencies/* /libtorrent-build${LIBDIR}

# 
# RELEASE
# 
FROM ubuntu
COPY --from=build-amd64 /libtorrent-build/ /lt-build/amd64/
COPY --from=build-arm64 /libtorrent-build/ /lt-build/arm64/
COPY --from=build-armhf /libtorrent-build/ /lt-build/arm/
