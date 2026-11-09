/*
 * The class/object/pointer counts in the header of an NSArchiver
 * archive (and of an NSPortCoder message) come from the data and are
 * only hints used to size the cross-reference tables.  Huge values
 * made GSIArrayInitWithZoneAndCapacity() compute the buffer size in
 * 32 bits, so a count of 0x20000000 allocated a zero length buffer that
 * was then written to (heap overflow), and other values requested
 * gigabytes of memory.  Found by fuzzing NSUnarchiver (ASan
 * heap-buffer-overflow in GSIArrayAddItem / out-of-memory).
 */
#import <Foundation/Foundation.h>
#import "Testing.h"

/* Overwrite the object count (the third hex field after the prefix).
 */
static NSData *
withCounts(NSData *archive, const char *prefix, const char *counts)
{
  NSMutableData	*m = AUTORELEASE([archive mutableCopy]);
  NSUInteger	plen = strlen(prefix);

  /* prefix, then "vvvvvvvv:" followed by the three counts */
  memcpy((char*)[m mutableBytes] + plen + 9, counts, strlen(counts));
  return m;
}

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSString		*str = @"hello world";
  NSData		*good;
  NSData		*bad;
  const char		*counts[] = {
    "20000000:20000000:20000000",
    "ffffffff:ffffffff:ffffffff",
    "10000000:10000000:10000000",
    0
  };
  unsigned		i;

  START_SET("NSUnarchiver header table sizes")

  good = [NSArchiver archivedDataWithRootObject: str];
  PASS_EQUAL([NSUnarchiver unarchiveObjectWithData: good], str,
    "unmodified archive decodes")
  for (i = 0; counts[i] != 0; i++)
    {
      id	o = nil;

      bad = withCounts(good, "GNUstep archive", counts[i]);
      NS_DURING
	o = [NSUnarchiver unarchiveObjectWithData: bad];
      NS_HANDLER
	o = nil;
      NS_ENDHANDLER
      PASS_EQUAL(o, str, "archive with table sizes %s decodes", counts[i])
    }

  END_SET("NSUnarchiver header table sizes")

  START_SET("NSPortCoder header table sizes")
  {
    NSPort	*port = [NSPort port];
    NSUInteger	r = [port reservedSpaceLength];
    NSPortCoder	*c;
    NSData	*d;

    c = [[NSPortCoder alloc] initWithReceivePort: port
					sendPort: port
				      components: nil];
    [c encodeObject: str];
    d = [[c performSelector: @selector(_components)] objectAtIndex: 0];
    good = [d subdataWithRange: NSMakeRange(r, [d length] - r)];
    RELEASE(c);

    for (i = 0; counts[i] != 0; i++)
      {
	id	o = nil;

	bad = withCounts(good, "GNUstep DO archive", counts[i]);
	NS_DURING
	  {
	    c = [[NSPortCoder alloc] initWithReceivePort: port
						sendPort: port
					      components:
	      [NSArray arrayWithObject: bad]];
	    o = [c decodeObject];
	    RELEASE(c);
	  }
	NS_HANDLER
	  o = nil;
	NS_ENDHANDLER
	PASS_EQUAL(o, str, "message with table sizes %s decodes", counts[i])
      }
  }
  END_SET("NSPortCoder header table sizes")

  [arp release];
  return 0;
}
