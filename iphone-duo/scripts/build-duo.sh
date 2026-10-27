#!/bin/sh
set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd)
source="$script_dir/duohid.m"
binary="$script_dir/duohid"

if [ -x "$binary" ] && [ "$binary" -nt "$source" ]; then
    exit 0
fi

temporary=$(mktemp "$binary.tmp.XXXXXX")
trap 'rm -f "$temporary"' EXIT
trap 'exit 1' HUP INT TERM
xcrun clang -fobjc-arc -framework Foundation -framework IOKit "$source" -o "$temporary"
chmod +x "$temporary"
mv -f "$temporary" "$binary"
