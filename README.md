# docker-libtorrent

Base image providing pre-built libtorrent with python-bindings

## Tags

```bash
{libtorrent_ver}-{base_image}-{py_ver}
```

| | description |
|---|---|
| ```libtorrent_ver```  | release version, i.e. ```1.2.6``` |
| ```base_image``` | base image with version, i.e. ```alpine3.11``` |
| ```py_ver``` | python major version, i.e. ```py2``` or ```py3``` |

## Usage

Libs are prepared in ```/libtorrent-build/usr/lib/``` so you can copy them to your own image as follows.

### Build

```Dockerfile
FROM wiserain/libtorrent:1.2.6-alpine3.11-py3 AS libtorrent
FROM alpine:3.11

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
1.2.6.0
```
