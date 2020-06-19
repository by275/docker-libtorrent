FROM ubuntu:18.04 AS ubuntu
FROM ubuntu AS build-base

ARG PY_MAJOR_VER
ARG LIBTORRENT_VER
ARG TARGETARCH
ARG DEBIAN_FRONTEND="noninteractive"
ARG CMAKE_VER=3.17.3

RUN \
    echo "**** install build-deps ****" && \
    apt-get update && \
    apt-get install -yq \
        build-essential \
        git \
        libssl-dev \
        libboost-chrono-dev \
        libboost-python-dev \
        libboost-random-dev \
        libboost-system-dev \
        pkg-config \
        wget

RUN \
    echo "**** install cmake ****" && \
    mkdir /tmp/cmake -p && \
    cd /tmp/cmake && \
    wget https://cmake.org/files/v${CMAKE_VER%.*}/cmake-${CMAKE_VER}.tar.gz && \
    tar -xzvf cmake-${CMAKE_VER}.tar.gz --strip-components=1 && \
    ./bootstrap && \
    make -j$(nproc) && \
    make install && \
    ln -s /usr/local/bin/cmake /usr/bin/cmake

RUN \
    echo "**** clone source ****" && \
    _LIBTORRENT_VER="$(echo "${LIBTORRENT_VER}" | sed 's/\./\_/g')" && \
    git clone https://github.com/arvidn/libtorrent.git /tmp/libtorrent -b "libtorrent-${_LIBTORRENT_VER}" || \
    git clone https://github.com/arvidn/libtorrent.git /tmp/libtorrent -b "libtorrent_${_LIBTORRENT_VER}"

RUN \
    echo "**** install python-deps ****" && \
    if [ $PY_MAJOR_VER = "2" ]; then \
        pydeps="python-setuptools python-all-dev"; \
    elif [ $PY_MAJOR_VER = "3" ]; then \
        pydeps="python3-setuptools python3-all-dev"; \
    fi && \
    apt-get install -yq ${pydeps}

RUN \
    echo "**** build libtorrent ****" && \
    PYTHON_VERSION=$(python${PY_MAJOR_VER} -c 'import sys; print(".".join([str(x) for x in sys.version_info[:2]]))') && \
    _PYTHON_VERSION="$(echo "${PYTHON_VERSION}" | sed 's/\.//g')" && \
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
        -DCMAKE_INSTALL_LIBDIR="lib" \
        -Dpython-bindings=ON \
        -Dboost-python-module-name="python${_PYTHON_VERSION}" \
        -DPython_ADDITIONAL_VERSIONS="${PYTHON_VERSION}" \
        -DBoost_LIBRARY_DIR="/usr/lib/${BOOST_LIB_DIR}" \
        "../" && \
    make VERBOSE=1 -j$(nproc) && \
    echo "**** install libtorrent ****" && \
    cd /tmp/libtorrent && \
    make -C "_build" DESTDIR=/libtorrent-build install && \
    rm -rf /libtorrent-build/usr/lib/cmake

FROM ubuntu
LABEL maintainer "wiserain"
COPY --from=build-base /libtorrent-build/usr/lib/ /libtorrent-build/usr/lib/
