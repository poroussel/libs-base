/*
 * The element count of an archived NSSet, NSCountedSet or NSDictionary
 * comes from the archive.  It was used directly as the initial capacity
 * of the hash map, which allocates and links that many nodes up front,
 * so an archive of a few dozen bytes could make the decoder use many
 * gigabytes of memory before failing.  Found by fuzzing NSUnarchiver
 * (libFuzzer out-of-memory in GSIMapInitWithZoneAndCapacity called from
 * -[GSSet initWithCoder:]).
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include <sys/resource.h>
#include <unistd.h>

static long
maxRSSkB(void)
{
  struct rusage	u;

  getrusage(RUSAGE_SELF, &u);
  return u.ru_maxrss;
}

/* Replace the first 32-bit unsigned value 2 (the element count) by a
 * huge value.
 */
static NSData *
hugeCount(NSData *archive)
{
  NSMutableData		*m = AUTORELEASE([archive mutableCopy]);
  unsigned char		*b = [m mutableBytes];
  NSUInteger		l = [m length];
  NSUInteger		i;

  for (i = 0; i + 5 <= l; i++)
    {
      if (b[i] == (_GSC_UINT | _GSC_I32) && b[i+1] == 0 && b[i+2] == 0
	&& b[i+3] == 0 && b[i+4] == 2)
	{
	  b[i+1] = 0x7f;
	  b[i+2] = b[i+3] = b[i+4] = 0xff;
	  return m;
	}
    }
  return nil;
}

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSString		*s1 = @"first string";
  NSString		*s2 = @"second string";
  NSArray		*objs;
  unsigned		i;

  alarm(60);

  START_SET("archived collection counts")

  objs = [NSArray arrayWithObjects:
    [NSSet setWithObjects: s1, s2, nil],
    [NSCountedSet setWithObjects: s1, s2, nil],
    [NSDictionary dictionaryWithObjectsAndKeys: s1, s2, s2, s1, nil],
    nil];
  for (i = 0; i < [objs count]; i++)
    {
      id	o = [objs objectAtIndex: i];
      NSData	*good = [NSArchiver archivedDataWithRootObject: o];
      NSData	*bad = hugeCount(good);
      const char	*n = [NSStringFromClass([o class]) UTF8String];
      long	before;
      id	r = nil;

      PASS_EQUAL([NSUnarchiver unarchiveObjectWithData: good], o,
	"%s archive decodes", n)
      PASS(bad != nil, "found the count in the %s archive", n)
      before = maxRSSkB();
      NS_DURING
	r = [NSUnarchiver unarchiveObjectWithData: bad];
      NS_HANDLER
	r = nil;
      NS_ENDHANDLER
      PASS(r == nil, "%s archive with a huge count is rejected", n)
      PASS(maxRSSkB() - before < 64 * 1024,
	"%s archive with a huge count does not use lots of memory", n)
    }

  END_SET("archived collection counts")

  [arp release];
  return 0;
}
