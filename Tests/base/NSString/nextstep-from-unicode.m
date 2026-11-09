/*
 * Conversion from Unicode to the NeXTSTEP encoding searches a table of
 * the characters it can represent.  The size given for that table (128)
 * was larger than the table (121 entries), so the search for a
 * character above the last entry read past the end of the table.
 * Found by fuzzing (ASan global-buffer-overflow in chop() called from
 * GSFromUnicode(), with Tests/fuzz/fuzz_encoding.m).
 * The over-read has no visible effect in a normal build; this test
 * detects it when the library is built with AddressSanitizer.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  unsigned		u;
  unsigned		converted = 0;
  BOOL			roundTrip = YES;
  unichar		c;
  NSString		*s;

  START_SET("NeXTSTEP encoding from Unicode")

  for (u = 0x80; u < 0x10000; u++)
    {
      NSData	*d;

      if (u >= 0xd800 && u < 0xe000)
	{
	  continue;	// Surrogates
	}
      c = u;
      s = [[NSString alloc] initWithCharacters: &c length: 1];
      d = [s dataUsingEncoding: NSNEXTSTEPStringEncoding];
      if ([d length] > 0)	// Byte order marks give empty data
	{
	  NSString	*r;

	  converted++;
	  r = [[NSString alloc] initWithData: d
				    encoding: NSNEXTSTEPStringEncoding];
	  if ([r isEqual: s] == NO)
	    {
	      roundTrip = NO;
	    }
	  [r release];
	}
      [s release];
    }
  PASS(converted == 121, "every non-ASCII NeXTSTEP character converts")
  PASS(roundTrip, "converted characters convert back")

  c = 0xfffd;
  s = [NSString stringWithCharacters: &c length: 1];
  PASS([s dataUsingEncoding: NSNEXTSTEPStringEncoding] == nil,
    "a character above the table does not convert")
  PASS([s canBeConvertedToEncoding: NSNEXTSTEPStringEncoding] == NO,
    "a character above the table cannot be converted")

  END_SET("NeXTSTEP encoding from Unicode")

  [arp release];
  return 0;
}
