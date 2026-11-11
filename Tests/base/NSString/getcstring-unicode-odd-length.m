/*
 * -getCString:maxLength:encoding: with NSUnicodeStringEncoding on a string
 * held as UTF-16 copied maxLength - 2 bytes, which for an odd maxLength
 * is half a character too many: it read one byte past the characters
 * wanted (past the end of the buffer for a whole string) and returned
 * YES with the start of a garbage character before the terminator.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"

#define	SIZE	16

static unsigned char	buf[SIZE];

static BOOL
convert(NSString *s, NSUInteger maxLength)
{
  memset(buf, 0xAA, SIZE);
  return [s getCString: (char*)buf
	     maxLength: maxLength
	      encoding: NSUnicodeStringEncoding];
}

static BOOL
untouched(unsigned from)
{
  while (from < SIZE)
    {
      if (buf[from++] != 0xAA)
	{
	  return NO;
	}
    }
  return YES;
}

static BOOL
holds(const unichar *u, unsigned count)
{
  unichar	c;
  unsigned	i;

  for (i = 0; i < count; i++)
    {
      memcpy(&c, buf + i * sizeof(unichar), sizeof(unichar));
      if (c != u[i])
	{
	  return NO;
	}
    }
  memcpy(&c, buf + count * sizeof(unichar), sizeof(unichar));
  return (0 == c) ? YES : NO;
}

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  unichar		euro[3] = { 0x20AC, 0x20AC, 0x20AC };
  NSString		*whole;
  NSString		*one;
  NSMutableString	*m;

  whole = [NSString stringWithCharacters: euro length: 3];
  /* A substring of a UTF-16 string uses its parent's characters, so the
   * byte after its last character is the start of the next one.
   */
  one = [whole substringToIndex: 1];
  m = [NSMutableString stringWithString: one];

  START_SET("UTF-16 string, odd buffer size")

  PASS([one length] == 1 && [m length] == 1, "strings have one character")
  PASS(convert(one, 5) == YES && holds(euro, 1) && untouched(4),
    "one character fits in 5 bytes and nothing follows the terminator")
  PASS(convert(m, 5) == YES && holds(euro, 1) && untouched(4),
    "same for a mutable string")
  PASS(convert(whole, 7) == NO && holds(euro, 2) && untouched(6),
    "three characters do not fit in 7 bytes, the first two are copied")
  PASS(convert(one, 3) == NO && holds(euro, 0) && untouched(2),
    "one character does not fit in 3 bytes")

  END_SET("UTF-16 string, odd buffer size")

  START_SET("UTF-16 string, even buffer size")

  PASS(convert(one, 4) == YES && holds(euro, 1) && untouched(4),
    "one character fits in 4 bytes")
  PASS(convert(whole, 8) == YES && holds(euro, 3) && untouched(8),
    "three characters fit in 8 bytes")
  PASS(convert(whole, 6) == NO && holds(euro, 2) && untouched(6),
    "three characters do not fit in 6 bytes")
  PASS([one getCString: 0 maxLength: 4 encoding: NSUnicodeStringEncoding]
    == NO, "a NULL buffer is refused")

  END_SET("UTF-16 string, even buffer size")

  [arp release];
  return 0;
}
