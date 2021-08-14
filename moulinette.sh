#!/usr/bin/env bash

set -eux

ffmpeg -i "$1" -vn -ar 16k -ac 1 -b:a 64k "$2"
