#!/bin/sh
set -eu
cd "$(dirname "$0")"
: "${THEOS:?Set THEOS to your Theos installation}"
exec make FINALPACKAGE=1 package
