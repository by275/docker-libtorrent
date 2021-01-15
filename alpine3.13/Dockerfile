FROM alpine:3.13 AS alpine
FROM alpine AS build-base

ARG PY_MAJOR_VER
ARG LIBTORRENT_VER

RUN \
    echo "**** install build-deps ****" && \
    apk add --no-cache --update \
        build-base \
        `# including file fortify-headers g++ gcc libc-dev make` \
        openssl-dev \
        boost-dev \
        git \
        cmake

RUN \
    echo "**** clone source ****" && \
    GIT_SSL_NO_VERIFY=0 git clone https://github.com/arvidn/libtorrent.git /tmp/libtorrent -b "v${LIBTORRENT_VER}" --depth 1

RUN \
    echo "**** install python-deps ****" && \
    if [ $PY_MAJOR_VER = "2" ]; then \
        pydeps="boost-python2 py2-setuptools python2-dev"; \
    elif [ $PY_MAJOR_VER = "3" ]; then \
        pydeps="boost-python3 py3-setuptools python3-dev"; \
    fi && \
    apk add --no-cache --update ${pydeps}

RUN \
    echo "**** build libtorrent ****" && \
    PYTHON_VERSION=$(python${PY_MAJOR_VER} -c 'import sys; print(".".join([str(x) for x in sys.version_info[:2]]))') && \
    mkdir /tmp/libtorrent/_build -p && \
    cd /tmp/libtorrent/_build && \
    cmake \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="/usr" \
        -DCMAKE_INSTALL_LIBDIR="lib" \
        -Dpython-bindings=ON \
        -Dboost-python-module-name="python${PYTHON_VERSION//./}" \
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
ARG PY_MAJOR_VER

COPY --from=build-base /libtorrent-build/usr/lib/ /usr/lib/

RUN \
    echo "**** install runtime packages ****" && \
    apk add --no-cache \
        libstdc++ \
        boost-system \
        boost-python${PY_MAJOR_VER} \
        python${PY_MAJOR_VER}

RUN \
    BUILD_VER=$(python${PY_MAJOR_VER} -c 'import libtorrent as lt; print(lt.version)') && \
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
LABEL maintainer "wiserain"
COPY --from=build-base /libtorrent-build/usr/lib/ /libtorrent-build/usr/lib/
