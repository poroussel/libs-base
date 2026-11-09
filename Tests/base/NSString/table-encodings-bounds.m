/*
 * The 8-bit encodings converted with a lookup table must not index past
 * the end of the table: the NeXTSTEP table has no entries for 0xfe and
 * 0xff, and GSM 03.38 is a 7-bit character set whose table has only
 * 128 entries.  Also, an escape (0x1b) as the last byte of GSM 03.38
 * data made the decoder read the byte after the end of the input.
 * Found by fuzzing NSUnarchiver (ASan global-buffer-overflow in
 * GSToUnicode() called from -[NSString initWithCoder:] for strings
 * archived with these encodings).
 */
#import <Foundation/Foundation.h>
#import "Testing.h"

static NSString *
decode(const char *bytes, unsigned len, NSStringEncoding enc)
{
  /* Use an exactly sized heap copy so that over-reads are detectable. */
  char		*b = malloc(len);
  NSString	*s;

  memcpy(b, bytes, len);
  s = AUTORELEASE([[NSString alloc] initWithBytes: b length: len
					   encoding: enc]);
  free(b);
  return s;
}

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSString		*s;

  START_SET("table based encodings")

  s = decode("A\xe9", 2, NSNEXTSTEPStringEncoding);
  PASS(s != nil && [s length] == 2 && [s characterAtIndex: 0] == 'A',
    "valid NeXTSTEP data converts")
  PASS(decode("A\xfe", 2, NSNEXTSTEPStringEncoding) == nil,
    "NeXTSTEP byte 0xfe (not in the character set) is rejected")
  PASS(decode("A\xff", 2, NSNEXTSTEPStringEncoding) == nil,
    "NeXTSTEP byte 0xff (not in the character set) is rejected")

  s = decode("A\xe9\xff", 3, NSISOCyrillicStringEncoding);
  PASS(s != nil && [s length] == 3, "Cyrillic data still converts")

  s = decode("Hello", 5, NSGSM0338StringEncoding);
  PASS_EQUAL(s, @"Hello", "valid GSM 03.38 data converts")
  PASS(decode("A\x80", 2, NSGSM0338StringEncoding) == nil,
    "GSM 03.38 byte above 0x7f is rejected")
  PASS(decode("A\xff", 2, NSGSM0338StringEncoding) == nil,
    "GSM 03.38 byte 0xff is rejected")
  s = decode("A\x1b", 2, NSGSM0338StringEncoding);
  PASS(s != nil && [s length] == 2,
    "GSM 03.38 data ending in an escape converts without over-reading")
  s = decode("\x1b\x65", 2, NSGSM0338StringEncoding);
  PASS(s != nil && [s length] == 1 && [s characterAtIndex: 0] == 0x20ac,
    "GSM 03.38 escape sequence for the euro sign converts")

  END_SET("table based encodings")

  [arp release];
  return 0;
}
