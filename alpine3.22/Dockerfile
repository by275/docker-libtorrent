FROM alpine:3.22 AS alpine

# 
# TEST
# 
FROM alpine AS test

ARG LT_VER
ARG TARGETARCH

COPY build/${TARGETARCH}/usr/ /usr/
COPY build/${TARGETARCH}/usr/ /libtorrent-build/usr/

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
