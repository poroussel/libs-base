/* GSFormat (-[NSString initWithFormat:...]) with a fuzzed format string.
 *
 * The arguments must match whatever the format asks for, so every
 * argument is the same pointer, to an immortal string object mapped at
 * the low fixed address 0x10000.  That value is safe however a directive
 * reads it: as an object (%@), a C or wide string (%s, %ls: the object's
 * bytes, which contain a nul soon), an integer or a '*' width/precision
 * (65536, so the padding stays reasonable), or a double (any bits).
 * 'n' (which stores through the argument) and '$' (positional arguments
 * could go beyond the 64 passed) are removed from the format, and runs
 * of digits are limited to 7: a larger width is valid but legitimately
 * produces gigabytes of padding.
 */
#include "fuzz_common.h"
#include <sys/mman.h>
#include <string.h>

#define	A	arg
#define	A8	A, A, A, A, A, A, A, A
#define	A64	A8, A8, A8, A8, A8, A8, A8, A8

static void
fuzz_one(NSData *data)
{
  static void	*arg = 0;
  NSUInteger	len = [data length];
  char		*buf;
  NSUInteger	i;
  NSUInteger	j;
  NSUInteger	digits = 0;
  NSString	*fmt;
  NSString	*s;

  if (arg == 0)
    {
      id	proto = @"immortal constant string";
      size_t	size = class_getInstanceSize(object_getClass(proto));

      arg = mmap((void*)0x10000, 4096, PROT_READ|PROT_WRITE,
	MAP_PRIVATE|MAP_ANONYMOUS|MAP_FIXED_NOREPLACE, -1, 0);
      if (arg != (void*)0x10000)
	abort();
      memcpy(arg, (void*)proto, size);
    }

  buf = malloc(len + 1);
  for (i = j = 0; i < len; i++)
    {
      char	c = ((const char*)[data bytes])[i];

      if (c == 'n' || c == '$' || c == 0)
	continue;
      if (c >= '0' && c <= '9')
	{
	  if (++digits > 7)
	    continue;	// Count the digits actually kept
	}
      else
	{
	  digits = 0;
	}
      buf[j++] = c;
    }
  buf[j] = 0;
  fmt = [[[NSString alloc] initWithBytesNoCopy: buf length: j
    encoding: NSISOLatin1StringEncoding freeWhenDone: YES] autorelease];

  s = [NSString stringWithFormat: fmt, A64];
  [s length];
  s = [[[NSString alloc] initWithFormat: fmt
    locale: [NSDictionary dictionary], A64] autorelease];
  [s length];
  s = [NSMutableString stringWithCapacity: 8];
  [(NSMutableString*)s appendFormat: fmt, A64];
}
