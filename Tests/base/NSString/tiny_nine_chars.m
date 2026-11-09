/*
 * Nine byte ASCII strings whose last byte is a nul must not be stored as
 * tiny strings: only eight 7-bit characters fit in a pointer, and the
 * ninth character would overlap the length/tag bits.  Found by fuzzing
 * GSMimeParser (stack buffer overflow in -[GSTinyString mutableCopyWithZone:]).
 */
#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSString.h>

int main(int argc, char **argv)
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  const char		*bytes = "abcdefgh";	/* 8 chars + nul */
  unichar		chars[9] = {'a','b','c','d','e','f','g','h',0};
  NSString		*s;
  NSString		*u;
  NSMutableString	*m;

  START_SET("nine character string ending in nul")

  s = AUTORELEASE([[NSString alloc] initWithBytes: bytes
					   length: 9
					 encoding: NSASCIIStringEncoding]);
  u = AUTORELEASE([[NSString alloc] initWithCharacters: chars length: 9]);

  PASS([s length] == 9, "string has length 9");
  PASS([s characterAtIndex: 8] == 0, "ninth character is a nul");
  PASS([s isEqual: u] && [u isEqual: s], "equals the unichar version");
  PASS([s hash] == [u hash], "hash matches the unichar version");

  m = AUTORELEASE([s mutableCopy]);
  PASS([m length] == 9 && [m characterAtIndex: 8] == 0,
    "mutable copy keeps all nine characters");
  PASS_EQUAL(m, u, "mutable copy is equal");
  PASS([s longLongValue] == 0, "longLongValue does not overflow");
  PASS_EQUAL([s substringToIndex: 8], @"abcdefgh", "substring is correct");
  PASS_EQUAL([[s substringToIndex: 8] stringByAppendingString: @"ijklmnop"],
    @"abcdefghijklmnop", "appending to the substring works");

  END_SET("nine character string ending in nul")

  [arp release];
  return 0;
}
