# docker-libtorrent

Base image providing pre-built libtorrent with python-bindings

## Tags

```bash
{libtorrent_ver}-{base_image}
```

| | description |
|---|---|
| ```libtorrent_ver```  | release version, e.g. ```2.0.5``` |
| ```base_image``` | base image with version, e.g. ```alpine3.15``` |

## Usage

Libs are prepared in ```/libtorrent-build/usr/lib/``` so you can copy them to your own image as follows.

### Build

```Dockerfile
ARG LT_VER=2.0.6
ARG ALPINE_VER=3.16

FROM ghcr.io/by275/libtorrent:${LT_VER}-alpine${ALPINE_VER} AS libtorrent
FROM alpine:${ALPINE_VER}

# install runtime library
RUN apk add --no-cache \
      libstdc++ \
      boost-system \
      boost-python3 \
      python3

# copy libtorrent libs
COPY --from=libtorrent /libtorrent-build/usr/lib/ /usr/lib/
```

```bash
docker build -t libtorrent-test .
```

### Test

```bash
>> docker run --rm libtorrent-test python3 -c 'import libtorrent; print(libtorrent.__version__)'
2.0.6.0
```
