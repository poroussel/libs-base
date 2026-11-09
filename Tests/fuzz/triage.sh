#!/bin/sh
# triage.sh <harness>: run every crash input, print a signature per input.
HERE=$(cd "$(dirname "$0")" && pwd)
t=$1
for f in "$HERE"/crashes/$t/crash-* "$HERE"/crashes/$t/timeout-* "$HERE"/crashes/$t/oom-*; do
  [ -f "$f" ] || continue
  out=$(ASAN_OPTIONS=detect_leaks=0:allocator_may_return_null=1 timeout 30 "$HERE/bin/$t" -timeout=10 -rss_limit_mb=2048 "$f" 2>&1)
  kind=$(echo "$out" | grep -oE "ERROR: (AddressSanitizer|libFuzzer): [a-zA-Z-]+( on unknown address)?|ERROR: libFuzzer: [a-z-]+" | head -1)
  frames=$(echo "$out" | grep -E "^ +#[0-9]+ " | grep -vE "libclang_rt|asan_|__interceptor|libc\.so|in (memcpy|memmove|strlen|strcmp)|fuzz_common|LLVMFuzzer|fuzzer::|__sanitizer_print_stack_trace|in _init" | head -3 | sed -E 's/.* in ([^ ]+( [^ ]+\])?).* ([^ ]+:[0-9]+).*/\1 \3/; s/.* in ([^ ]+).*/\1/' | sed -E 's|/[^ ]*/||g' | tr '\n' '|')
  echo "$(basename "$f")	$kind	$frames"
done
