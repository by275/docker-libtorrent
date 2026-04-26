FROM alpine:3.21 AS alpine

#
# BUILD
#
FROM alpine AS build-base

ARG LT_VER

ENV GIT_SSL_NO_VERIFY=0

RUN \
    echo "**** install build-deps ****" && \
    apk add --no-cache --update \
        build-base \
        openssl-dev \
        boost-dev \
        git \
        cmake \
        boost-python3 py3-setuptools python3-dev \
        clang lld apk-tools

RUN \
    echo "**** clone source ****" && \
    git clone --recurse-submodules https://github.com/arvidn/libtorrent.git /tmp/libtorrent -b "v${LT_VER}" --depth 1

#
# CROSS COMPILE
#
FROM build-base AS build-amd64

RUN \
    echo "**** build libtorrent for amd64 ****" && \
    PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str,sys.version_info[:2])))') && \
    mkdir -p /tmp/libtorrent/_build-amd64 && \
    cd /tmp/libtorrent/_build-amd64 && \
    cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="/usr" \
        -DCMAKE_INSTALL_LIBDIR="lib" \
        -Dpython-bindings=ON \
        -Dboost-python-module-name="python${PYTHON_VERSION//./}" \
        "../" && \
    make -j$(nproc) && \
    echo "**** install libtorrent for amd64 ****" && \
    make DESTDIR=/libtorrent-build install && \
    rm -rf /libtorrent-build/usr/lib/cmake

FROM build-base AS build-arm64

RUN \
    echo "**** install arm64 sysroot ****" && \
    mkdir -p /sysroot/etc/apk && \
    cp /etc/apk/repositories /sysroot/etc/apk/repositories && \
    apk --root /sysroot --arch aarch64 --allow-untrusted --initdb add --no-cache \
        gcc g++ \
        musl-dev \
        openssl-dev \
        boost-dev \
        boost-python3 \
        python3-dev \
        libstdc++ && \
    echo "**** write cmake toolchain ****" && \
    { \
        echo "set(CMAKE_SYSTEM_NAME Linux)"; \
        echo "set(CMAKE_SYSTEM_PROCESSOR aarch64)"; \
        echo "set(CMAKE_SYSROOT /sysroot)"; \
        echo "set(CMAKE_C_COMPILER clang)"; \
        echo "set(CMAKE_CXX_COMPILER clang++)"; \
        echo "set(CMAKE_C_COMPILER_TARGET aarch64-alpine-linux-musl)"; \
        echo "set(CMAKE_CXX_COMPILER_TARGET aarch64-alpine-linux-musl)"; \
        echo "set(CMAKE_EXE_LINKER_FLAGS_INIT \"-fuse-ld=lld\")"; \
        echo "set(CMAKE_SHARED_LINKER_FLAGS_INIT \"-fuse-ld=lld\")"; \
        echo "set(CMAKE_MODULE_LINKER_FLAGS_INIT \"-fuse-ld=lld\")"; \
        echo "set(CMAKE_FIND_ROOT_PATH /sysroot)"; \
        echo "set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)"; \
        echo "set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)"; \
        echo "set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)"; \
        echo "set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)"; \
    } > /tmp/aarch64-alpine-linux-musl.cmake

RUN \
    echo "**** build libtorrent for arm64 ****" && \
    PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str,sys.version_info[:2])))') && \
    mkdir -p /tmp/libtorrent/_build-arm64 && \
    cd /tmp/libtorrent/_build-arm64 && \
    cmake \
        -DCMAKE_TOOLCHAIN_FILE=/tmp/aarch64-alpine-linux-musl.cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="/usr" \
        -DCMAKE_INSTALL_LIBDIR="lib" \
        -Dpython-bindings=ON \
        -Dboost-python-module-name="python${PYTHON_VERSION//./}" \
        -DPython3_EXECUTABLE=/usr/bin/python3 \
        -DPython3_INCLUDE_DIR=/sysroot/usr/include/python${PYTHON_VERSION} \
        -DPython3_LIBRARY=/sysroot/usr/lib/libpython${PYTHON_VERSION}.so \
        "../" && \
    make -j$(nproc) && \
    echo "**** install libtorrent for arm64 ****" && \
    make DESTDIR=/libtorrent-build install && \
    rm -rf /libtorrent-build/usr/lib/cmake

FROM build-base AS build-arm

RUN \
    echo "**** install armv7 sysroot ****" && \
    mkdir -p /sysroot/etc/apk && \
    cp /etc/apk/repositories /sysroot/etc/apk/repositories && \
    apk --root /sysroot --arch armv7 --allow-untrusted --initdb add --no-cache \
        gcc g++ \
        musl-dev \
        openssl-dev \
        boost-dev \
        boost-python3 \
        python3-dev \
        libstdc++ && \
    echo "**** write cmake toolchain ****" && \
    { \
        echo "set(CMAKE_SYSTEM_NAME Linux)"; \
        echo "set(CMAKE_SYSTEM_PROCESSOR armv7)"; \
        echo "set(CMAKE_SYSROOT /sysroot)"; \
        echo "set(CMAKE_C_COMPILER clang)"; \
        echo "set(CMAKE_CXX_COMPILER clang++)"; \
        echo "set(CMAKE_C_COMPILER_TARGET armv7-alpine-linux-musleabihf)"; \
        echo "set(CMAKE_CXX_COMPILER_TARGET armv7-alpine-linux-musleabihf)"; \
        echo "set(CMAKE_EXE_LINKER_FLAGS_INIT \"-fuse-ld=lld\")"; \
        echo "set(CMAKE_SHARED_LINKER_FLAGS_INIT \"-fuse-ld=lld\")"; \
        echo "set(CMAKE_MODULE_LINKER_FLAGS_INIT \"-fuse-ld=lld\")"; \
        echo "set(CMAKE_FIND_ROOT_PATH /sysroot)"; \
        echo "set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)"; \
        echo "set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)"; \
        echo "set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)"; \
        echo "set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)"; \
    } > /tmp/armv7-alpine-linux-musleabihf.cmake

RUN \
    echo "**** build libtorrent for armv7 ****" && \
    PYTHON_VERSION=$(python3 -c 'import sys; print(".".join(map(str,sys.version_info[:2])))') && \
    mkdir -p /tmp/libtorrent/_build-arm && \
    cd /tmp/libtorrent/_build-arm && \
    cmake \
        -DCMAKE_TOOLCHAIN_FILE=/tmp/armv7-alpine-linux-musleabihf.cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="/usr" \
        -DCMAKE_INSTALL_LIBDIR="lib" \
        -Dpython-bindings=ON \
        -Dboost-python-module-name="python${PYTHON_VERSION//./}" \
        -DPython3_EXECUTABLE=/usr/bin/python3 \
        -DPython3_INCLUDE_DIR=/sysroot/usr/include/python${PYTHON_VERSION} \
        -DPython3_LIBRARY=/sysroot/usr/lib/libpython${PYTHON_VERSION}.so \
        "../" && \
    make -j$(nproc) && \
    echo "**** install libtorrent for armv7 ****" && \
    make DESTDIR=/libtorrent-build install && \
    rm -rf /libtorrent-build/usr/lib/cmake

#
# RELEASE
#
FROM alpine
COPY --from=build-amd64 /libtorrent-build/ /lt-build/amd64/
COPY --from=build-arm64 /libtorrent-build/ /lt-build/arm64/
COPY --from=build-arm /libtorrent-build/ /lt-build/arm/
