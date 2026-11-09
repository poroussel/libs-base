/* Character set conversion (GSToUnicode / GSFromUnicode and the NSString
 * methods built on them).  The first byte picks one of the available
 * encodings, the second byte picks options; the rest is converted to a
 * string with that encoding and, read as UTF-16, from a string to it.
 */
#include "fuzz_common.h"

static NSStringEncoding	*encs = 0;
static unsigned		nencs = 0;

static void
fromString(NSString *s, NSStringEncoding enc, uint8_t opt)
{
  NSUInteger	len = [s length];
  char		buf[17];
  NSUInteger	used;
  NSRange	rest;

  [s dataUsingEncoding: enc allowLossyConversion: YES];
  [s dataUsingEncoding: enc allowLossyConversion: NO];
  [s canBeConvertedToEncoding: enc];
  [s lengthOfBytesUsingEncoding: enc];
  [s maximumLengthOfBytesUsingEncoding: enc];
  [s cStringUsingEncoding: enc];
  /* Small buffer, partial ranges. */
  [s getBytes: buf
    maxLength: (opt & 15) + 1
   usedLength: &used
     encoding: enc
      options: (opt & 16) ? NSStringEncodingConversionAllowLossy : 0
	range: NSMakeRange(len / 3, len - len / 3)
remainingRange: &rest];
  [s getCString: buf maxLength: (opt & 15) + 1 encoding: enc];
}

static void
fuzz_one(NSData *data)
{
  const uint8_t		*b = [data bytes];
  NSUInteger		l = [data length];
  NSStringEncoding	enc;
  uint8_t		opt;
  NSData		*rest;
  NSString		*s;

  if (encs == 0)
    {
      NSStringEncoding	*e = [NSString availableStringEncodings];

      encs = e;
      while (e[nencs] != 0)
	nencs++;
    }
  if (l < 2)
    return;
  enc = encs[b[0] % nencs];
  opt = b[1];
  rest = [data subdataWithRange: NSMakeRange(2, l - 2)];

  s = [[[NSString alloc] initWithData: rest encoding: enc] autorelease];
  if (s != nil)
    {
      [s length];
      [s description];
      fromString(s, enc, opt);
    }
  s = [[[NSString alloc] initWithBytes: [rest bytes]
				length: [rest length]
			      encoding: enc] autorelease];
  if (s != nil)
    {
      [[[NSString alloc] initWithBytesNoCopy: (void*)[rest bytes]
				      length: [rest length]
				    encoding: enc
				freeWhenDone: NO] autorelease];
    }
  if ([rest length] >= 2)
    {
      /* Arbitrary UTF-16 (including lone surrogates) to the encoding. */
      s = [[[NSString alloc] initWithCharacters: (const unichar*)[rest bytes]
					 length: [rest length] / 2] autorelease];
      fromString(s, enc, opt);
    }
}
