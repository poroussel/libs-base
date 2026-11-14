#!/bin/sh
# Run harnesses once over their corpus: replay.sh <harness>...
# Called by 'make replay'; a quick check that inputs which used to be
# handled still are.  Exits with status 1 if one of the runs fails.
HERE=$(cd "$(dirname "$0")" && pwd)
BIN=${FUZZ_BIN:-$HERE/obj}
export ASAN_OPTIONS=${ASAN_OPTIONS:-detect_leaks=0:allocator_may_return_null=1:handle_abort=1}
ulimit -c 0
status=0
for t in "$@"; do
  if [ ! -d "$HERE/corpus/$t" ]; then
    "$BIN/seedgen" "$HERE/corpus" || exit 2
    mkdir -p "$HERE/corpus/$t"
  fi
  mkdir -p "$HERE/logs"
  n=$(ls "$HERE/corpus/$t" | wc -l)
  if "$BIN/$t" -runs=0 -timeout=10 -rss_limit_mb=2048 $FUZZ_ARGS \
    "$HERE/corpus/$t" > "$HERE/logs/$t.replay.log" 2>&1; then
    echo "$t: $n inputs, ok"
  else
    echo "$t: FAILED (see logs/$t.replay.log)"
    status=1
  fi
done
exit $status
