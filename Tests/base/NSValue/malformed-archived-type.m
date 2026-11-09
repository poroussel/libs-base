/*
 * The type encoding of an archived NSValue comes from the archive and
 * is passed to runtime functions (objc_sizeof_type() etc) which abort()
 * the process on an unknown type, or read beyond the end of a malformed
 * structure encoding.  -initWithCoder: must reject such encodings with
 * an exception instead.  Found by fuzzing NSUnarchiver (abort() in the
 * runtime's sizeof_type() called via NSGetSizeAndAlignment() from
 * -[NSValue initWithCoder:]).
 */
#import <Foundation/Foundation.h>
#import "Testing.h"

typedef struct { int a; int b; } pair;

/* Replace the first occurrence of 'from' by 'to' (same length). */
static NSData *
patch(NSData *archive, const char *from, const char *to)
{
  NSMutableData	*m = AUTORELEASE([archive mutableCopy]);
  char		*b = [m mutableBytes];
  NSUInteger	l = [m length];
  NSUInteger	n = strlen(from);
  NSUInteger	i;

  for (i = 0; i + n <= l; i++)
    {
      if (memcmp(b + i, from, n) == 0)
	{
	  memcpy(b + i, to, n);
	  return m;
	}
    }
  return nil;
}

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  pair			p = { 3, 4 };
  int			arr[4] = { 1, 2, 3, 4 };
  NSValue		*v;
  NSData		*good;
  const char		*badTypes[] = {
    "{pair_type=iz}",	/* unknown element type */
    "{pair_type=ii",	/* missing closing brace */
    "{pair_type}ii}",	/* garbage after opaque structure */
    "{pair{type=ii}",	/* bracket inside name */
    "{pair_type=[i}",	/* unterminated array */
    "{pair_type=b1}",	/* incomplete bit-field */
    0
  };
  unsigned		i;

  START_SET("NSValue archived type encodings")

  v = [NSValue valueWithBytes: &p objCType: "{pair_type=ii}"];
  good = [NSArchiver archivedDataWithRootObject: v];
  PASS_EQUAL([NSUnarchiver unarchiveObjectWithData: good], v,
    "valid structure value round trips")

  v = [NSValue valueWithBytes: arr objCType: @encode(int[4])];
  PASS_EQUAL([NSUnarchiver unarchiveObjectWithData:
    [NSArchiver archivedDataWithRootObject: v]], v,
    "valid array value round trips")

  v = [NSValue valueWithRange: NSMakeRange(10, 20)];
  PASS_EQUAL([NSUnarchiver unarchiveObjectWithData:
    [NSArchiver archivedDataWithRootObject: v]], v,
    "range value round trips")

  for (i = 0; badTypes[i] != 0; i++)
    {
      NSData	*bad = patch(good, "{pair_type=ii}", badTypes[i]);
      id	o = nil;

      if (strlen(badTypes[i]) != strlen("{pair_type=ii}"))
	{
	  /* Shorter types are padded with nul characters. */
	  char	buf[15];

	  memset(buf, 0, sizeof(buf));
	  strcpy(buf, badTypes[i]);
	  bad = patch(good, "{pair_type=ii}", buf);
	}
      PASS(bad != nil, "made archive with type %s", badTypes[i])
      PASS_EXCEPTION(o = [NSUnarchiver unarchiveObjectWithData: bad],
	NSInvalidArgumentException,
	"archived value with type %s raises an exception", badTypes[i])
    }

  END_SET("NSValue archived type encodings")

  [arp release];
  return 0;
}
