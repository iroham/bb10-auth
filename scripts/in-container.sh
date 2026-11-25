#!/bin/bash
# Run a script from native-auth/scripts inside the build container. From anywhere: native-auth/scripts/in-container.sh <script> [args]
# Mounts: /src AOSP tree (clang), /qnxsdk BB10 SDK, /w phase6 (toolchain + host moc), /t native-auth, /b build volume.
cd "$(dirname "$0")/../.."
DOCKER_CONTEXT=colima-aosp docker run --rm -v a11-src:/src -v $PWD/phase6/qnxsdk:/qnxsdk:ro -v $PWD/phase6:/w -v $PWD/native-auth:/t -v tg-build:/b -w /b a11-build bash /t/scripts/"$@" 2>&1 | grep -v "requested image"
exit ${PIPESTATUS[0]}
