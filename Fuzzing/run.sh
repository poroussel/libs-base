#!/bin/sh
# Fuzz harnesses one after the other: run.sh <seconds> <harness>[:<maxlen>]...
# Called by 'make fuzz'.  FUZZ_BIN is the directory holding the built
# harnesses (default obj), FUZZ_ENGINE libfuzzer (the default) or
# standalone (see standalone.c), FUZZ_ARGS extra options for it.  The
# default maximum input length is 8192 bytes (MAXLEN in the environment
# overrides it for every harness).
# The evolving corpus is kept in corpus/<harness>/ (created by seedgen
# on the first run), reproducers in crashes/<harness>/, the output in
# logs/<harness>.log.  Exits with status 1 if new reproducers were saved.
HERE=$(cd "$(dirname "$0")" && pwd)
BIN=${FUZZ_BIN:-$HERE/obj}
secs=$1; shift
export ASAN_OPTIONS=${ASAN_OPTIONS:-detect_leaks=0:allocator_may_return_null=1:handle_abort=1}
ulimit -c 0
found=0
for arg in "$@"; do
  t=${arg%%:*}
  len=${MAXLEN:-8192}
  [ "$arg" != "$t" ] && [ -z "$MAXLEN" ] && len=${arg#*:}
  if [ ! -d "$HERE/corpus/$t" ]; then
    "$BIN/seedgen" "$HERE/corpus" || exit 2
    mkdir -p "$HERE/corpus/$t"
  fi
  mkdir -p "$HERE/crashes/$t" "$HERE/logs"
  before=$(ls "$HERE/crashes/$t" | wc -l)
  echo "Fuzzing $t for ${secs}s (log in logs/$t.log)"
  if [ "$FUZZ_ENGINE" = standalone ]; then
    # The driver stops at the first crash: start it again until the
    # time is up.
    end=$(( $(date +%s) + secs ))
    (cd "$HERE/crashes/$t" &&
      while left=$(( end - $(date +%s) )); [ $left -gt 0 ]; do
        "$BIN/$t" -max_total_time=$left -timeout=10 -max_len=$len \
          -artifact_prefix="$HERE/crashes/$t/" $FUZZ_ARGS "$HERE/corpus/$t"
      done) > "$HERE/logs/$t.log" 2>&1
  else
    (cd "$HERE/crashes/$t" &&
      "$BIN/$t" -fork=1 -ignore_crashes=1 -ignore_timeouts=1 -ignore_ooms=1 \
        -max_total_time=$secs -timeout=10 -rss_limit_mb=2048 -max_len=$len \
        -artifact_prefix="$HERE/crashes/$t/" $FUZZ_ARGS "$HERE/corpus/$t" \
        > "$HERE/logs/$t.log" 2>&1)
  fi
  grep -E '^#[0-9]+' "$HERE/logs/$t.log" | tail -1 | sed 's/^/  /'
  new=$(( $(ls "$HERE/crashes/$t" | wc -l) - before ))
  if [ $new -gt 0 ]; then
    echo "  $new new reproducer(s) in crashes/$t/"
    found=1
  fi
done
if [ $found = 1 ]; then
  echo "New crashes were found: run 'make triage' for a summary."
  exit 1
fi
