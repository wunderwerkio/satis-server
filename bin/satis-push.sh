#!/usr/bin/env sh
. /satis-server/bin/scw-functions.sh
set -e

repo=$1
if [ -z "$repo" ]; then
  repo=$2
fi

/satis-server/bin/satis-build.sh "$repo"
