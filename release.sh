#!/bin/bash

LIBTORRENT_VER="$1"
TAGS="$2"
U_ID=$(/usr/bin/id -u)
G_ID=$(/usr/bin/id -g)

# prepare binfmt and qemu-static
export DOCKER_CLI_EXPERIMENTAL=enabled
docker run --rm --privileged docker/binfmt:a7996909642ee92942dcd6cff44b9b95f08dad64
docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

mkdir -p $(pwd)/release

for TAG in $TAGS; do
    BASE_IMAGE="wiserain/libtorrent:${LIBTORRENT_VER}-${TAG}"
    for manifest in $(docker buildx imagetools inspect --raw ${BASE_IMAGE} | jq -r '.manifests[] | @base64'); do
        arch=$(echo $manifest | base64 --decode | jq -r '.platform.architecture')
        digest=$(echo $manifest | base64 --decode | jq -r '.digest')
        file="/release/libtorrent-${LIBTORRENT_VER}-${TAG}-$arch.tar.gz"
        docker run --rm -v $(pwd)/release:/release ${BASE_IMAGE}@${digest} \
            sh -c "apk add tar && tar -C /libtorrent-build -zcvf $file usr && chown $U_ID:$G_ID $file"
    done
done
