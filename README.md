# docker-libtorrent

Base image providing pre-built libtorrent with python-bindings

## Tags

```bash
{libtorrent_ver}-{base_image}
```

| | description |
|---|---|
| ```libtorrent_ver```  | release version, e.g. ```1.2.15``` |
| ```base_image``` | base image with version, e.g. ```alpine3.15``` |

## Usage

Libs are prepared in ```/libtorrent-build/usr/lib/``` so you can copy them to your own image as follows.

### Build

```Dockerfile
FROM ghcr.io/by275/libtorrent:1.2.15-alpine3.15 AS libtorrent
FROM alpine:3.15

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
1.2.15.0
```
