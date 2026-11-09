#!/bin/sh
# Build the libFuzzer harnesses against a libgnustep-base built with
#   make -C Source debug=yes \
#     ADDITIONAL_OBJCFLAGS="-fsanitize=address,fuzzer-no-link" \
#     ADDITIONAL_CFLAGS="-fsanitize=address,fuzzer-no-link" \
#     ADDITIONAL_LDFLAGS="-fsanitize=address"
# Usage: Tests/fuzz/build.sh [harness...]   (run from anywhere)
set -e
HERE=$(cd "$(dirname "$0")" && pwd)
TOP=$(cd "$HERE/../.." && pwd)
CC=${CC:-clang}
OUT=${OUT:-$HERE/bin}
mkdir -p "$OUT"
OBJCFLAGS=$(gnustep-config --objc-flags | sed -e 's/-O2//' -e 's/-MMD//' -e 's/-MP//')
TARGETS=${*:-$(cd "$HERE" && ls fuzz_*.m | sed 's/\.m$//')}
LIBS="-L$TOP/Source/obj -Wl,--disable-new-dtags,-rpath,$TOP/Source/obj -lgnustep-base $(gnustep-config --base-libs | sed 's/-lgnustep-base//')"
for t in $TARGETS; do
  echo "building $t"
  $CC $OBJCFLAGS -O1 -g -fsanitize=fuzzer,address -fno-omit-frame-pointer \
    -I"$TOP/Headers" -I"$TOP/Source/obj" \
    "$HERE/$t.m" -o "$OUT/$t" $LIBS
done
# The seed generator is a plain program (no libFuzzer main).
echo "building seedgen"
$CC $OBJCFLAGS -O1 -g -fsanitize=address -I"$TOP/Headers" -I"$TOP/Source/obj" \
  "$HERE/seedgen.m" -o "$OUT/seedgen" $LIBS
