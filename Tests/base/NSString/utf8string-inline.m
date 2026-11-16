#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSData.h>
#import <Foundation/NSString.h>
#include <string.h>

/* -UTF8String of 8-bit strings, which for inline strings with ASCII
 * content returns the string's own (nul terminated) characters.  The
 * result must be right however the string was made, and must stay valid
 * until the autorelease pool is drained even if the string is released
 * (run with an AddressSanitizer build to check the latter).
 */
static BOOL
utf8Is(NSString *s, const char *expected)
{
  const char	*u = [s UTF8String];

  return u != 0 && strcmp(u, expected) == 0;
}

int main()
{
  START_SET("UTF8String of inline strings")
  const char		*ascii = "The quick brown fox jumps over the lazy dog";
  NSAutoreleasePool	*pool;
  NSString		*s;
  NSMutableString	*m;
  const char		*u;
  const char		*u2;
  char			copy[64];

  s = [NSString stringWithUTF8String: ascii];
  PASS(utf8Is(s, ascii), "ASCII string from UTF-8");
  u = [s UTF8String];
  u2 = [s UTF8String];
  PASS(strcmp(u, u2) == 0 && strlen(u) == [s length],
    "repeated calls give the same characters");

  pool = [NSAutoreleasePool new];
  s = [[NSString alloc] initWithUTF8String: ascii];
  u = [s UTF8String];
  [s release];
  strncpy(copy, u, sizeof(copy) - 1);
  copy[sizeof(copy) - 1] = 0;
  PASS(strcmp(copy, ascii) == 0,
    "result stays valid after the string is released, until the pool goes");
  [pool release];

  s = [NSString stringWithFormat: @"%d %s and %@", 42, "bytes", @"more"];
  PASS(utf8Is(s, "42 bytes and more"), "result of a format");

  s = [[NSString stringWithUTF8String: ascii] substringWithRange:
    NSMakeRange(4, 15)];
  PASS(utf8Is(s, "quick brown fox"), "substring");

  s = [[NSString stringWithUTF8String: ascii] uppercaseString];
  PASS(utf8Is(s, "THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG"),
    "uppercase copy");

  m = [NSMutableString stringWithUTF8String: ascii];
  s = [[m copy] autorelease];
  u = [s UTF8String];
  [m replaceCharactersInRange: NSMakeRange(0, 3) withString: @"A"];
  PASS(strcmp(u, ascii) == 0 && utf8Is(s, ascii),
    "immutable copy is not affected by changes to the original");
  PASS(utf8Is(m, "A quick brown fox jumps over the lazy dog"),
    "and the mutable string has its own content");

  u = "caf\xe9 au lait, cr\xe8me br\xfbl\xe9" "e";
  s = [[[NSString alloc] initWithBytes: u length: strlen(u)
    encoding: NSISOLatin1StringEncoding] autorelease];
  PASS(utf8Is(s, "caf\xc3\xa9 au lait, cr\xc3\xa8me br\xc3\xbbl\xc3\xa9" "e"),
    "Latin-1 content is still converted");

  s = [[[NSString alloc] initWithBytes: "abc\0defghijkl" length: 13
    encoding: NSASCIIStringEncoding] autorelease];
  PASS([s length] == 13 && utf8Is(s, "abc"),
    "embedded nul: the C string stops there, as before");

  s = [[[NSString alloc] initWithBytes: "x" length: 0
    encoding: NSASCIIStringEncoding] autorelease];
  PASS(utf8Is(s, ""), "empty string");

  END_SET("UTF8String of inline strings")
  return 0;
}
