/*
 * The GNUstep binary property list format (NSSerializer) stores the
 * number of elements/bytes of each container or string in front of it.
 * Those counts come from the data and must be checked against the
 * amount of data remaining before being used to size allocations;
 * otherwise a few bytes of input can make the deserializer allocate
 * (and for dictionaries initialise) many gigabytes of memory.  Found by
 * fuzzing NSPropertyListSerialization and NSKeyedUnarchiver (libFuzzer
 * out-of-memory in deserializeFromInfo()).
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

static id
decode(const char *bytes, unsigned len, BOOL *raised)
{
  NSData	*d = [NSData dataWithBytes: bytes length: len];
  id		o = nil;

  *raised = NO;
  NS_DURING
    o = [NSDeserializer deserializePropertyListFromData: d
				      mutableContainers: NO];
  NS_HANDLER
    *raised = YES;
  NS_ENDHANDLER
  return o;
}

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  struct { const char *name; const char *bytes; unsigned len; } bad[] = {
    { "array",		"\0\003\177\377\377\377\001\0\0\0\002a", 12 },
    { "dictionary",	"\0\005\177\377\377\377\001\0\0\0\002a", 12 },
    { "unicode string",	"\0\002\177\377\377\377a\0", 8 },
    { "C string",	"\0\001\377\377\377\377a", 7 },
    { "data",		"\0\007\377\377\377\377\001\002\003", 9 },
  };
  unsigned		i;
  id			o;
  BOOL			raised;
  NSData		*good;

  alarm(60);

  START_SET("NSSerializer element counts")

  good = [NSSerializer serializePropertyList:
    [NSArray arrayWithObjects: @"ab", [NSDictionary dictionaryWithObject:
    [NSData dataWithBytes: "xyz" length: 3] forKey: @"key"], nil]];
  o = [NSDeserializer deserializePropertyListFromData: good
				    mutableContainers: NO];
  PASS([o count] == 2 && [[o objectAtIndex: 0] isEqual: @"ab"]
    && [[[o objectAtIndex: 1] objectForKey: @"key"] length] == 3,
    "valid serialized property list decodes")

  for (i = 0; i < sizeof(bad)/sizeof(*bad); i++)
    {
      long	before = maxRSSkB();

      o = decode(bad[i].bytes, bad[i].len, &raised);
      PASS(o == nil, "%s with a huge count is rejected", bad[i].name)
      PASS(maxRSSkB() - before < 64 * 1024,
	"%s with a huge count does not use lots of memory", bad[i].name)
    }

  END_SET("NSSerializer element counts")

  [arp release];
  return 0;
}
