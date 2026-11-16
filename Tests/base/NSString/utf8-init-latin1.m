#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSString.h>
#include <string.h>

/* -initWithUTF8String: must give the same string as the general UTF-8
 * conversion (-initWithBytes:length:encoding:), whatever storage it
 * chooses; strings stored differently must still compare equal and
 * have the same hash.  With a Latin-1 internal encoding, UTF-8 data
 * whose characters are all in Latin-1 is stored as 8-bit characters.
 */
static NSString *
viaBytes(const char *u)
{
  return [[[NSString alloc] initWithBytes: u length: strlen(u)
    encoding: NSUTF8StringEncoding] autorelease];
}

static BOOL
same(const char *u)
{
  NSString	*a = [NSString stringWithUTF8String: u];
  NSString	*b = viaBytes(u);
  NSUInteger	i;

  if (a == nil || b == nil)
    {
      return a == b;
    }
  if ([a length] != [b length] || [a isEqual: b] == NO
    || [b isEqual: a] == NO || [a hash] != [b hash])
    {
      return NO;
    }
  for (i = 0; i < [a length]; i++)
    {
      if ([a characterAtIndex: i] != [b characterAtIndex: i])
	{
	  return NO;
	}
    }
  return strcmp([a UTF8String], u) == 0;
}

int main()
{
  START_SET("initWithUTF8String: with Latin-1 content")
  char			all[2 * 128 + 1];
  char			*p = all;
  NSString		*s;
  NSMutableString	*m;
  NSStringEncoding	eightBit;
  unsigned		i;

  PASS(same("caf\xc3\xa9"), "short Latin-1 string");
  PASS(same("Le c\xc3\xa9l\xc3\xa8" "bre fran\xc3\xa7" "ais na\xc3\xaf" "f"),
    "longer Latin-1 string");
  PASS(same("\xc2\x80"), "U+0080 alone");
  PASS(same("\xc3\xbf"), "U+00FF alone");
  PASS(same("abc\xc3\xbf"), "U+00FF at the end");
  PASS(same("\xc4\x80 is past Latin-1"), "U+0100 is not Latin-1");
  PASS(same("caf\xc3\xa9 10 \xe2\x82\xac"), "Latin-1 then a euro sign");
  PASS(same("smile \xf0\x9f\x98\x80 caf\xc3\xa9"), "Latin-1 and a surrogate pair");

  for (i = 0x80; i <= 0xff; i++)
    {
      *p++ = 0xc0 | (i >> 6);
      *p++ = 0x80 | (i & 0x3f);
    }
  *p = 0;
  s = [NSString stringWithUTF8String: all];
  PASS([s length] == 128, "all of U+0080..U+00FF: 128 characters");
  for (i = 0; i < 128; i++)
    {
      if ([s characterAtIndex: i] != 0x80 + i)
	{
	  break;
	}
    }
  PASS(i == 128, "all of U+0080..U+00FF: right characters");
  PASS(same(all), "all of U+0080..U+00FF: same as the general conversion");

  PASS([NSString stringWithUTF8String: "caf\xc3"] == nil,
    "truncated sequence at the end is rejected");
  PASS(same("caf\xc3"), "truncated sequence: same as the general conversion");
  PASS([NSString stringWithUTF8String: "caf\xc3(x"] == nil,
    "lead byte without continuation is rejected");
  PASS([NSString stringWithUTF8String: "\xc0\x80"] == nil,
    "overlong encoding of nul is rejected");
  PASS([NSString stringWithUTF8String: "\xc1\xbf"] == nil,
    "overlong encoding of U+007F is rejected");
  PASS([NSString stringWithUTF8String: "\xc3\xa9\x80"] == nil,
    "stray continuation byte is rejected");
  s = [NSString stringWithUTF8String: "\xef\xbb\xbf" "caf\xc3\xa9"];
  PASS([s length] == 4 && [s isEqual: viaBytes("caf\xc3\xa9")],
    "leading BOM is skipped");

  /* An 8-bit string made from Latin-1 bytes tells us whether the
   * internal encoding is Latin-1 (and so whether the UTF-8 data should
   * be stored as 8-bit characters too).
   */
  eightBit = [[[[NSString alloc] initWithBytes: "caf\xe9 cr\xe8me" length: 10
    encoding: NSISOLatin1StringEncoding] autorelease] smallestEncoding];
  s = [NSString stringWithUTF8String: "caf\xc3\xa9 cr\xc3\xa8me br\xc3\xbbl\xc3\xa9" "e"];
  if (eightBit == NSISOLatin1StringEncoding)
    {
      PASS([s smallestEncoding] == NSISOLatin1StringEncoding,
	"Latin-1 content from UTF-8 is stored as 8-bit characters");
    }
  PASS([[NSString stringWithUTF8String: "10 \xe2\x82\xac"] smallestEncoding]
    == NSUnicodeStringEncoding, "a euro sign needs UTF-16");

  /* The same characters held as UTF-16 (a mutable string widened by
   * a euro sign that is then removed) compare equal and hash the same.
   */
  m = [NSMutableString stringWithString: @"€"];
  [m appendString: s];
  [m deleteCharactersInRange: NSMakeRange(0, 1)];
  PASS([m smallestEncoding] == NSUnicodeStringEncoding, "copy is UTF-16");
  PASS([m isEqual: s] && [s isEqual: m], "8-bit and UTF-16 copies are equal");
  PASS([m hash] == [s hash], "8-bit and UTF-16 copies hash the same");
  PASS([s compare: m] == NSOrderedSame, "and compare the same");

  END_SET("initWithUTF8String: with Latin-1 content")
  return 0;
}
