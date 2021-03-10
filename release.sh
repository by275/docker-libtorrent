#!/bin/bash

LIBTORRENT_VER="$1"
TAGS="$2"
U_ID=$(/usr/bin/id -u)
G_ID=$(/usr/bin/id -g)

mkdir -p $(pwd)/release

for TAG in $TAGS; do
    BASE_IMAGE="ghcr.io/wiserain/libtorrent:${LIBTORRENT_VER}-${TAG}"
    for manifest in $(docker buildx imagetools inspect --raw ${BASE_IMAGE} | jq -r '.manifests[] | @base64'); do
        arch=$(echo $manifest | base64 --decode | jq -r '.platform.architecture')
        digest=$(echo $manifest | base64 --decode | jq -r '.digest')
        file="/release/libtorrent-${LIBTORRENT_VER}-${TAG}-$arch.tar.gz"
        if [[ $TAG == "alpine"* ]]; then
            docker run --rm -v $(pwd)/release:/release ${BASE_IMAGE}@${digest} \
                sh -c "apk add tar && tar -C /libtorrent-build -zcvf $file usr && chown $U_ID:$G_ID $file"
        elif [[ $TAG == "ubuntu"* ]]; then
            docker run --rm -v $(pwd)/release:/release ${BASE_IMAGE}@${digest} \
                sh -c "tar -C /libtorrent-build -zcvf $file usr && chown $U_ID:$G_ID $file"
        fi
    done
done
