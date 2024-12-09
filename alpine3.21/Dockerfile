FROM alpine:3.21 AS alpine

# 
# BUILD
# 
FROM alpine AS build-base

ARG LT_VER

ENV GIT_SSL_NO_VERIFY=0 \
    BOOST_ROOT="" \
    BOOST_BUILD_PATH=/usr/share/boost-build/src/kernel \
    BUILD_CONFIG="release cxxstd=14 link=shared crypto=openssl warnings=off toolset=gcc"

RUN \
    echo "**** install build-deps ****" && \
    apk add --no-cache --update \
        build-base \
        boost-build \
        boost-dev \
        git \
        openssl-dev \
        `# python-deps` \
        boost-python3 py3-setuptools python3-dev

RUN \
    echo "**** clone source ****" && \
    git clone --recurse-submodules https://github.com/arvidn/libtorrent.git /tmp/libtorrent -b "v${LT_VER}" --depth 1

# RUN \
#     echo "**** build libtorrent-rasterbar ****" && \
#     cd /tmp/libtorrent && \
#     b2 -j$(nproc) ${BUILD_CONFIG} \
#         address-model=$(getconf LONG_BIT) \
#         link=shared

RUN \
    echo "**** prepare python envs ****" && \
    PY_VER=$(python3 -c 'import sys; print(".".join(map(str,sys.version_info[:2])))') && \
    ABIFLAGS=$(python3 -c 'import sys; print(sys.abiflags)') && \
    EXT_SUFFIX=$(python3 -c 'import sysconfig; print(sysconfig.get_config_var("EXT_SUFFIX"))') && \
    echo "using python : ${PY_VER} : /usr/bin/python${PY_VER} : /usr/include/python${PY_VER}${ABIFLAGS} : /usr/lib/python${PY_VER} : : ${EXT_SUFFIX%%.so} ;" > /root/user-config.jam && \
    echo "**** build python-bindings ****" && \
    cd /tmp/libtorrent/bindings/python && \
    b2  -j$(nproc) ${BUILD_CONFIG} \
        address-model=$(getconf LONG_BIT) \
        libtorrent-link=shared \
        boost-link=shared \
        stage_module \
        stage_dependencies && \
    echo "**** collect build artifacts ****" && \
    PY_PKG_DIR=$(python3 -c 'import site; print(site.getsitepackages()[0])') && \
    mkdir -p /libtorrent-build${PY_PKG_DIR} && \
    mv /tmp/libtorrent/bindings/python/*.so /libtorrent-build${PY_PKG_DIR}/ && \
    LIBDIR=$(python3 -c 'import sysconfig; print(sysconfig.get_config_var("LIBDIR"))') && \
    mkdir -p /libtorrent-build${LIBDIR} && \
    mv /tmp/libtorrent/bindings/python/dependencies/* /libtorrent-build${LIBDIR}

# 
# TEST
# 
FROM alpine AS test

ARG LT_VER

COPY --from=build-base /libtorrent-build/usr/ /usr/
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
FROM scratch
LABEL maintainer="by275"
LABEL org.opencontainers.image.source=https://github.com/by275/docker-libtorrent
COPY --from=test /libtorrent-build/usr/lib/ /libtorrent-build/usr/lib/
