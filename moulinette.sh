#!/usr/bin/env bash

set -eux

ffmpeg -i "$1" -vn -filter:a "speechnorm=e=6.25:r=0.00001:l=1" -ar 16k -ac 1 -b:a 64k "$2"
