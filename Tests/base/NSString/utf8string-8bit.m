#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSData.h>
#import <Foundation/NSString.h>
#include <string.h>

/* -UTF8String of strings stored as 8-bit characters (ASCII and Latin-1
 * content, immutable, substrings and mutable strings) must give the same
 * bytes as -dataUsingEncoding: NSUTF8StringEncoding, nul terminated.
 */
static BOOL
sameAsData(NSString *s)
{
  NSData	*d = [s dataUsingEncoding: NSUTF8StringEncoding];
  const char	*u = [s UTF8String];

  return u != 0 && strlen(u) == [d length]
    && memcmp(u, [d bytes], [d length]) == 0;
}

int main()
{
  START_SET("UTF8String of 8-bit strings")
  unsigned char	all[255];
  NSString	*s;
  NSString	*t;
  NSMutableString	*m;
  const char	*u;
  const char	*l1;
  unsigned	i;

  s = [NSString stringWithUTF8String: "The quick brown fox jumps"];
  PASS(strcmp([s UTF8String], "The quick brown fox jumps") == 0,
    "ASCII string gives its bytes");
  PASS(sameAsData(s), "ASCII string matches dataUsingEncoding:");

  l1 = "caf\xe9 cr\xe8me br\xfbl\xe9" "e";
  s = [[[NSString alloc] initWithBytes: l1 length: strlen(l1)
    encoding: NSISOLatin1StringEncoding] autorelease];
  PASS([s length] == 17, "Latin-1 string has 17 characters");
  PASS(strcmp([s UTF8String],
    "caf\xc3\xa9 cr\xc3\xa8me br\xc3\xbbl\xc3\xa9" "e") == 0,
    "Latin-1 characters are encoded as two UTF-8 bytes");
  PASS(sameAsData(s), "Latin-1 string matches dataUsingEncoding:");
  PASS([[NSString stringWithUTF8String: [s UTF8String]] isEqual: s],
    "Latin-1 string survives a UTF-8 round trip");

  for (i = 0; i < 255; i++)
    {
      all[i] = i + 1;
    }
  s = [[[NSString alloc] initWithBytes: all length: 255
    encoding: NSISOLatin1StringEncoding] autorelease];
  u = [s UTF8String];
  PASS(strlen(u) == 127 + 2 * 128, "every Latin-1 character: right length");
  PASS(sameAsData(s), "every Latin-1 character matches dataUsingEncoding:");
  PASS((unsigned char)u[126] == 0x7f && (unsigned char)u[127] == 0xc2
    && (unsigned char)u[128] == 0x80, "U+007F then U+0080");
  PASS((unsigned char)u[127 + 2 * 128 - 2] == 0xc3
    && (unsigned char)u[127 + 2 * 128 - 1] == 0xbf, "U+00FF last");

  s = [NSString stringWithUTF8String: "0123456789abcdefghijklmnopqrstuvwxyz"];
  t = [s substringWithRange: NSMakeRange(10, 20)];
  PASS(strcmp([t UTF8String], "abcdefghijklmnopqrst") == 0,
    "ASCII substring stops at its own end");

  l1 = "\xe0 la carte, \xe0 la mode, tr\xe8s bien";
  s = [[[NSString alloc] initWithBytes: l1 length: strlen(l1)
    encoding: NSISOLatin1StringEncoding] autorelease];
  t = [s substringWithRange: NSMakeRange(2, 20)];
  PASS(sameAsData(t), "Latin-1 substring matches dataUsingEncoding:");
  PASS([[NSString stringWithUTF8String: [t UTF8String]] isEqual: t],
    "Latin-1 substring survives a UTF-8 round trip");

  m = [NSMutableString stringWithString: s];
  [m appendString: @" and more"];
  PASS(sameAsData(m), "mutable Latin-1 string matches dataUsingEncoding:");
  [m setString: @""];
  PASS(strcmp([m UTF8String], "") == 0, "empty mutable string gives \"\"");

  END_SET("UTF8String of 8-bit strings")
  return 0;
}
