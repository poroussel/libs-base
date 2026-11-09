#!/bin/sh
# Run one harness: run.sh <harness> <seconds>
# Crashes go to crashes/<harness>/, the evolving corpus to corpus/<harness>/.
HERE=$(cd "$(dirname "$0")" && pwd)
t=$1; secs=${2:-300}
mkdir -p "$HERE/corpus/$t" "$HERE/crashes/$t" "$HERE/logs"
cd "$HERE/crashes/$t"
ASAN_OPTIONS=detect_leaks=0:allocator_may_return_null=1 \
  "$HERE/bin/$t" -fork=1 -ignore_crashes=1 -ignore_timeouts=1 -ignore_ooms=1 \
  -max_total_time=$secs -timeout=10 -rss_limit_mb=2048 -max_len=8192 \
  -artifact_prefix="$HERE/crashes/$t/" "$HERE/corpus/$t" \
  > "$HERE/logs/$t.log" 2>&1
