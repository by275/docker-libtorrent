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
        libssl-dev \
        `# python-deps` \
        python3-setuptools python3-all-dev

ENV CMAKE_VER="3.19.2"
RUN \
    echo "**** install cmake v${CMAKE_VER} ****" && \
    apt-get update && \
    apt-get install -yq \
        build-essential \
        libssl-dev \
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
        -- \
        -DCMAKE_BUILD_TYPE:STRING=Release && \
    make -j$(nproc) && \
    make install

RUN \
    echo "**** clone source ****" && \
    GIT_SSL_NO_VERIFY=0 git clone https://github.com/arvidn/libtorrent.git /tmp/libtorrent -b "v${LIBTORRENT_VER}" --depth 1

RUN \
    echo "**** build libtorrent ****" && \
    PY_VER=$(python3 -c 'import sys; print(".".join([str(x) for x in sys.version_info[:2]]))') && \
    _PY_VER="$(echo "${PY_VER}" | sed 's/\.//g')" && \
    if [ $TARGETARCH = "amd64" ]; then \
        BOOST_LIB_DIR="x86_64-linux-gnu"; \
    elif [ $TARGETARCH = "arm64" ]; then \
        BOOST_LIB_DIR="aarch64-linux-gnu"; \
    elif [ $TARGETARCH = "arm" ]; then \
        BOOST_LIB_DIR="arm-linux-gnueabihf"; \
    fi && \
    mkdir /tmp/libtorrent/_build -p && \
    cd /tmp/libtorrent/_build && \
    cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="/usr" \
        -DCMAKE_INSTALL_LIBDIR="lib/${BOOST_LIB_DIR}" \
        -Dpython-bindings=ON \
        -Dboost-python-module-name="python${_PY_VER}" \
        "../" && \
    make VERBOSE=1 -j$(nproc) && \
    echo "**** install libtorrent ****" && \
    cd /tmp/libtorrent && \
    make -C "_build" DESTDIR=/libtorrent-build install && \
    rm -rf /libtorrent-build/usr/lib/cmake

# 
# TEST
# 
FROM ubuntu AS test

ARG LIBTORRENT_VER
ARG TARGETARCH
ARG DEBIAN_FRONTEND="noninteractive"

COPY --from=build-base /libtorrent-build/usr/lib/ /usr/lib/

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
COPY --from=build-base /libtorrent-build/usr/lib/ /libtorrent-build/usr/lib/
