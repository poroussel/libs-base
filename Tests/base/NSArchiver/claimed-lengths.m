/*
 * NSString, NSArray and NSValue -initWithCoder: (and NSUnarchiver's
 * -decodeDataObject, used by NSData) read a length or count from the
 * archive and allocated a buffer of that size before decoding the
 * contents.  When the archive is shorter than claimed, decoding
 * raises and the buffer was leaked, so each malformed archive (or
 * Distributed Objects message) could leak gigabytes of address space.
 * Found by fuzzing NSUnarchiver and NSPortCoder (libFuzzer
 * out-of-memory in -[NSString initWithCoder:], -[GSPlaceholderArray
 * initWithCoder:], -[NSValue initWithCoder:] and -[NSUnarchiver
 * decodeDataObject]).
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include <stdio.h>
#include <unistd.h>

/* Virtual memory size in megabytes, or -1 if unknown. */
static long
vmSizeMB(void)
{
  FILE	*f = fopen("/proc/self/statm", "r");
  long	pages = -1;

  if (f != NULL)
    {
      if (fscanf(f, "%ld", &pages) != 1)
	{
	  pages = -1;
	}
      fclose(f);
    }
  return (pages < 0) ? -1 : pages * (sysconf(_SC_PAGESIZE) / 1024) / 1024;
}

/* Replace the first 32-bit unsigned value 'from' (tag _GSC_UINT|_GSC_I32)
 * by 0x10000000.
 */
static NSData *
hugeLength(NSData *archive, unsigned from)
{
  NSMutableData		*m = AUTORELEASE([archive mutableCopy]);
  unsigned char		*b = [m mutableBytes];
  NSUInteger		l = [m length];
  NSUInteger		i;

  for (i = 0; i + 5 <= l; i++)
    {
      if (b[i] == (_GSC_UINT | _GSC_I32) && b[i+1] == 0 && b[i+2] == 0
	&& b[i+3] == 0 && b[i+4] == from)
	{
	  b[i+1] = 0x10;
	  b[i+4] = 0;
	  return m;
	}
    }
  return nil;
}

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  struct { const char *name; id obj; unsigned len; } cases[4];
  unsigned		i;
  long			before;

  cases[0].name = "NSString";
  cases[0].obj = [NSString stringWithFormat: @"hello world %C", 0x20ac];
  cases[0].len = 13;
  cases[1].name = "NSArray";
  cases[1].obj = [NSArray arrayWithObjects: @"first string",
    @"second string", nil];
  cases[1].len = 2;
  cases[2].name = "NSValue";
  cases[2].obj = [NSValue valueWithRange: NSMakeRange(1, 2)];
  cases[2].len = strlen(@encode(NSRange)) + 1;
  cases[3].name = "NSData";
  cases[3].obj = [NSData dataWithBytes: "some bytes of data" length: 18];
  cases[3].len = 18;

  START_SET("claimed lengths in archives")

  for (i = 0; i < 4; i++)
    {
      NSData	*good = [NSArchiver archivedDataWithRootObject: cases[i].obj];
      NSData	*bad = hugeLength(good, cases[i].len);
      unsigned	j;

      PASS_EQUAL([NSUnarchiver unarchiveObjectWithData: good], cases[i].obj,
	"%s archive decodes", cases[i].name)
      PASS(bad != nil, "found the length in the %s archive", cases[i].name)
      before = vmSizeMB();
      for (j = 0; j < 8; j++)
	{
	  id	o = nil;

	  NS_DURING
	    o = [NSUnarchiver unarchiveObjectWithData: bad];
	  NS_HANDLER
	    o = nil;
	  NS_ENDHANDLER
	  if (o != nil)
	    break;
	}
      PASS(j == 8, "%s archive with a huge length is rejected", cases[i].name)
      if (before < 0)
	{
	  SKIP("/proc/self/statm not available")
	}
      PASS(vmSizeMB() - before < 512,
	"rejecting %s archives with a huge length does not leak memory",
	cases[i].name)
    }

  END_SET("claimed lengths in archives")

  [arp release];
  return 0;
}
