#!/bin/sh
# triage.sh <harness>...: run every saved crash input, print a signature
# per input.  Called by 'make triage'; FUZZ_BIN is the directory holding
# the built harnesses (default obj).
HERE=$(cd "$(dirname "$0")" && pwd)
BIN=${FUZZ_BIN:-$HERE/obj}
ulimit -c 0
# Run in a scratch directory: the engine writes a new reproducer there
# when the input crashes again.
TMP=$(mktemp -d) || exit 1
trap 'rm -rf "$TMP"' EXIT
cd "$TMP" || exit 1
for t in "$@"; do
for f in "$HERE"/crashes/$t/crash-* "$HERE"/crashes/$t/timeout-* "$HERE"/crashes/$t/oom-*; do
  [ -f "$f" ] || continue
  out=$(ASAN_OPTIONS=${ASAN_OPTIONS:-detect_leaks=0:allocator_may_return_null=1:handle_abort=1} timeout 30 "$BIN/$t" -timeout=10 -rss_limit_mb=2048 "$f" 2>&1)
  kind=$(echo "$out" | grep -oE "ERROR: (AddressSanitizer|libFuzzer): [a-zA-Z-]+( on unknown address)?|ERROR: libFuzzer: [a-z-]+|ERROR: standalone: [a-z ]+" | head -1)
  frames=$(echo "$out" | grep -E "^ +#[0-9]+ " | grep -vE "libclang_rt|asan_|__interceptor|libc\.so|in (memcpy|memmove|strlen|strcmp)|fuzz_common|LLVMFuzzer|fuzzer::|__sanitizer_print_stack_trace|in _init|pthread_kill|in (raise|abort|gsignal) " | head -3 | sed -E 's/.* in ([^ ]+( [^ ]+\])?).* ([^ ]+:[0-9]+).*/\1 \3/; s/.* in ([^ ]+).*/\1/' | sed -E 's|/[^ ]*/||g' | tr '\n' '|')
  echo "$t/$(basename "$f")	$kind	$frames"
done
done
