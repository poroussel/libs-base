/*
 * UTF-16 data (NSUnicodeStringEncoding) starting with a byte order mark
 * for the other byte order is byte swapped by fixBOM() in GSString.m.
 * With an odd number of bytes the swapping loop read one byte past the
 * end of the data and wrote one byte past the end of the buffer it had
 * allocated.  Found by fuzzing (ASan heap-buffer-overflow in fixBOM()
 * with Tests/fuzz/fuzz_encoding.m).
 * The overflow is only detected when the library is built with
 * AddressSanitizer; the results are checked in any build.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"

static NSString *
decode(const char *bytes, unsigned len)
{
  /* Use an exactly sized heap copy so that overflows are detectable. */
  char		*b = malloc(len);
  NSString	*s;

  memcpy(b, bytes, len);
  s = AUTORELEASE([[NSString alloc] initWithBytes: b length: len
					   encoding: NSUnicodeStringEncoding]);
  free(b);
  return s;
}

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSString		*le;
  NSString		*be;

  START_SET("UTF-16 with a byte order mark and an odd length")

  le = decode("\xff\xfe" "A\0B\0C", 7);
  be = decode("\xfe\xff" "\0A\0B\0", 7);
  PASS_EQUAL(le, @"AB", "little endian: the incomplete last unit is ignored")
  PASS_EQUAL(be, @"AB", "big endian: the incomplete last unit is ignored")
  PASS_EQUAL(decode("\xff\xfe" "A", 3), @"",
    "little endian: a single byte after the mark gives an empty string")
  PASS_EQUAL(decode("\xfe\xff" "\0", 3), @"",
    "big endian: a single byte after the mark gives an empty string")
  PASS_EQUAL(decode("\xfe\xff" "\0A\0B", 6), @"AB",
    "big endian data with an even length converts")
  PASS_EQUAL(decode("\xff\xfe" "A\0B\0", 6), @"AB",
    "little endian data with an even length converts")

  END_SET("UTF-16 with a byte order mark and an odd length")

  [arp release];
  return 0;
}
