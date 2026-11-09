/* NSScanner: the first bytes choose a sequence of scan operations and
 * the scanner options, the rest (after the first '\n') is the string.
 */
#include "fuzz_common.h"

static void
fuzz_one(NSData *data)
{
  const uint8_t	*b = [data bytes];
  NSUInteger	len = [data length];
  NSUInteger	nops = 0;
  NSString	*s;
  NSScanner	*sc;
  NSUInteger	i;

  while (nops < len && b[nops] != '\n')
    nops++;
  if (nops >= len)
    return;
  s = [[[NSString alloc] initWithBytes: b + nops + 1
				length: len - nops - 1
			      encoding: NSUTF8StringEncoding] autorelease];
  if (s == nil)
    return;
  sc = [NSScanner scannerWithString: s];
  if (nops > 0 && (b[0] & 0x80))
    [sc setCaseSensitive: YES];
  if (nops > 0 && (b[0] & 0x40))
    [sc setCharactersToBeSkipped: nil];
  if (nops > 0 && (b[0] & 0x20))
    [sc setLocale: [NSDictionary dictionaryWithObjectsAndKeys:
      @",", NSDecimalSeparator, nil]];
  for (i = 1; i < nops && i < 64 && ![sc isAtEnd]; i++)
    {
      int		iv;
      NSInteger		nv;
      long long		llv;
      unsigned long long	ullv;
      unsigned		uv;
      float		fv;
      double		dv;
      NSDecimal		dec;
      NSString		*str;

      switch (b[i] % 17)
	{
	  case 0: [sc scanInt: &iv]; break;
	  case 1: [sc scanInteger: &nv]; break;
	  case 2: [sc scanLongLong: &llv]; break;
	  case 3: [sc scanUnsignedLongLong: &ullv]; break;
	  case 4: [sc scanHexInt: &uv]; break;
	  case 5: [sc scanHexLongLong: &ullv]; break;
	  case 6: [sc scanFloat: &fv]; break;
	  case 7: [sc scanDouble: &dv]; break;
	  case 8: [sc scanHexFloat: &fv]; break;
	  case 9: [sc scanHexDouble: &dv]; break;
	  case 10:
	    if ([sc scanDecimal: &dec])
	      NSDecimalString(&dec, nil);
	    break;
	  case 11: [sc scanString: @"ab" intoString: &str]; break;
	  case 12: [sc scanUpToString: @"x" intoString: &str]; break;
	  case 13: [sc scanCharactersFromSet:
	    [NSCharacterSet alphanumericCharacterSet] intoString: &str]; break;
	  case 14: [sc scanUpToCharactersFromSet:
	    [NSCharacterSet whitespaceCharacterSet] intoString: &str]; break;
	  case 15: [sc setScanLocation: b[i] % ([s length] + 1)]; break;
	  case 16: [sc scanRadixUnsignedInt: &uv]; break;
	}
    }
}
