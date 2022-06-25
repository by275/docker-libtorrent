#!/bin/bash

LT_VER="$1"
TAGS="$2"
U_ID=$(/usr/bin/id -u)
G_ID=$(/usr/bin/id -g)

mkdir -p $(pwd)/release

for TAG in $TAGS; do
    BASE_IMAGE="ghcr.io/by275/libtorrent:${LT_VER}-${TAG}"
    for manifest in $(docker buildx imagetools inspect --raw ${BASE_IMAGE} | jq -r '.manifests[] | @base64'); do
        arch=$(echo $manifest | base64 --decode | jq -r '.platform.architecture')
        digest=$(echo $manifest | base64 --decode | jq -r '.digest')
        file="/release/libtorrent-${LT_VER}-${TAG}-$arch.tar.gz"
        docker build -t lt:release -<<EOF
FROM alpine
RUN apk add --no-cache tar
COPY --from=${BASE_IMAGE}@${digest} /libtorrent-build /lt
EOF
        docker run --rm -v $(pwd)/release:/release lt:release sh -c "tar -C /lt -zcvf $file usr && chown $U_ID:$G_ID $file"
    done
done
