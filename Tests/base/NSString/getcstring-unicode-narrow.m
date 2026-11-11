/*
 * -getCString:maxLength:encoding: with NSUnicodeStringEncoding on a string
 * held in the internal 8-bit encoding passed the buffer size in bytes to
 * GSToUnicode(), which measures it in characters, so it wrote up to about
 * twice maxLength bytes (a 5 character string wrote 12 bytes into a 10
 * byte buffer).  It also returned NO when the string did fit.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"

#define	SIZE	32

static unsigned char	buf[SIZE];

/* Fill the buffer with a marker, convert, and return the number of bytes
 * at the start of the buffer which may have been written (the offset just
 * after the last byte which no longer holds the marker).
 */
static unsigned
convert(NSString *s, NSUInteger maxLength, BOOL *result)
{
  unsigned	used = 0;
  unsigned	i;

  memset(buf, 0xAA, SIZE);
  *result = [s getCString: (char*)buf
		maxLength: maxLength
		 encoding: NSUnicodeStringEncoding];
  for (i = 0; i < SIZE; i++)
    {
      if (buf[i] != 0xAA)
	{
	  used = i + 1;
	}
    }
  return used;
}

static BOOL
holds(const char *ascii)
{
  const unichar	*u = (const unichar*)(void*)buf;
  unsigned	i;

  for (i = 0; ascii[i] != '\0'; i++)
    {
      if (u[i] != (unichar)ascii[i])
	{
	  return NO;
	}
    }
  return (0 == u[i]) ? YES : NO;
}

static void
check(NSString *s, const char *kind)
{
  BOOL	ok;

  START_SET(kind)

  PASS(convert(s, 10, &ok) <= 10 && ok == YES && holds("abcd"),
    "4 characters fit in 10 bytes and are nul terminated")
  PASS(convert(s, 11, &ok) <= 11 && ok == YES && holds("abcd"),
    "4 characters fit in 11 bytes")

  END_SET(kind)
}

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSString		*s;
  BOOL			ok;

  /* Strings made by -initWithFormat: are held in the internal 8-bit
   * encoding (and are never tiny strings).
   */
  check([NSString stringWithFormat: @"%s", "abcd"], "8-bit string");
  check([NSMutableString stringWithFormat: @"%s", "abcd"],
    "8-bit mutable string");

  START_SET("8-bit string too long for the buffer")

  s = [NSString stringWithFormat: @"%s", "abcde"];
  PASS(convert(s, 10, &ok) <= 10 && ok == NO,
    "5 characters do not fit in 10 bytes, nothing written beyond them")
  s = [NSString stringWithFormat: @"%s", "abcdefgh"];
  PASS(convert(s, 10, &ok) <= 10 && ok == NO,
    "8 characters do not fit in 10 bytes, nothing written beyond them")
  s = [NSMutableString stringWithFormat: @"%s", "abcdefg"];
  PASS(convert(s, 15, &ok) <= 15 && ok == NO,
    "7 characters do not fit in 15 bytes, nothing written beyond them")
  PASS(convert(s, 1, &ok) == 0 && ok == NO,
    "nothing is written to a buffer smaller than a character")

  END_SET("8-bit string too long for the buffer")

  START_SET("empty 8-bit string")

  s = [NSMutableString string];
  PASS(convert(s, 2, &ok) <= 2 && ok == YES && holds(""),
    "an empty string fits in 2 bytes")

  END_SET("empty 8-bit string")

  [arp release];
  return 0;
}
