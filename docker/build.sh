#!/bin/bash
cwd=$(pwd | xargs basename)
echo "Building container image for $cwd."
if [[ "$cwd" != "one-to-one" ]]; then
  echo "Run this from the repository root. That is, this script should be run as './docker/build.sh'."
  exit 1
fi

docker build -f docker/Dockerfile -t one-to-one .