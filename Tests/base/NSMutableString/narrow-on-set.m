#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSString.h>
#include <string.h>

/* A mutable string that had to use UTF-16 (for a character outside the
 * internal 8-bit encoding) goes back to 8-bit characters when -setString:
 * replaces its whole content with a string held as 8-bit characters, or
 * empties it.  The content must be right whatever the storage, and the
 * string must keep working (growing, widening again) afterwards.
 */
static BOOL
check(NSMutableString *m, NSString *expected)
{
  return [m isEqual: expected] && [expected isEqual: m]
    && [m length] == [expected length] && [m hash] == [expected hash]
    && strcmp([m UTF8String], [expected UTF8String]) == 0;
}

static NSMutableString *
wideString(void)
{
  NSMutableString	*m = [NSMutableString stringWithCapacity: 4];

  [m appendString: @"price: 10 €"];
  return m;
}

int main()
{
  START_SET("GSMutableString goes back to 8-bit characters")
  NSString		*ascii;
  NSString		*latin1;
  NSString		*expected;
  NSMutableString	*m;
  NSMutableString	*eight;
  BOOL			byteInternal;
  unichar		chars[] = {'a', 0x20ac, 'b', 'c'};
  unichar		*buf;
  int			i;

  ascii = [NSString stringWithUTF8String:
    "The quick brown fox jumps over the lazy dog"];
  latin1 = [[[NSString alloc] initWithBytes: "caf\xe9 cr\xe8me br\xfbl\xe9" "e"
    length: 17 encoding: NSISOLatin1StringEncoding] autorelease];
  byteInternal = ([ascii smallestEncoding] != NSUnicodeStringEncoding);

  m = wideString();
  PASS([m smallestEncoding] == NSUnicodeStringEncoding,
    "a euro sign makes the string UTF-16");
  [m setString: ascii];
  PASS(check(m, ascii), "setString: an 8-bit ASCII string: right content");
  if (byteInternal)
    {
      PASS([m smallestEncoding] != NSUnicodeStringEncoding,
	"setString: an 8-bit ASCII string: back to 8-bit characters");
    }

  m = wideString();
  [m setString: latin1];
  PASS(check(m, latin1), "setString: a Latin-1 string: right content");
  if ([latin1 smallestEncoding] != NSUnicodeStringEncoding)
    {
      PASS([m smallestEncoding] != NSUnicodeStringEncoding,
	"setString: a Latin-1 string: back to 8-bit characters");
    }

  m = wideString();
  [m setString: @"a literal string, longer than a tiny one"];
  PASS(check(m, @"a literal string, longer than a tiny one"),
    "setString: an ASCII literal: right content");

  m = wideString();
  [m setString: [NSString stringWithUTF8String: "tiny"]];
  PASS(check(m, @"tiny"), "setString: a tiny string: right content");

  eight = [NSMutableString stringWithString: @"an 8-bit mutable string"];
  m = wideString();
  [m setString: eight];
  PASS(check(m, eight), "setString: an 8-bit mutable string: right content");
  m = wideString();
  [m setString: [[eight copy] autorelease]];
  PASS(check(m, eight), "setString: a copy of it: right content");
  m = wideString();
  [m setString: [ascii substringFromIndex: 4]];
  PASS(check(m, [ascii substringFromIndex: 4]),
    "setString: an 8-bit substring: right content");

  m = wideString();
  [m setString: @""];
  PASS([m length] == 0 && [m isEqual: @""], "setString: empty string");
  if (byteInternal)
    {
      PASS([m smallestEncoding] != NSUnicodeStringEncoding,
	"setString: empty string: back to 8-bit characters");
    }
  [m appendString: ascii];
  PASS(check(m, ascii), "append after emptying");

  m = wideString();
  [m setString: @"café €"];
  PASS([m smallestEncoding] == NSUnicodeStringEncoding,
    "setString: a UTF-16 string stays UTF-16");
  PASS(check(m, @"café €"), "and has the right content");

  /* Fill the reused buffer and beyond, then widen again.
   */
  m = wideString();
  [m setString: @"x"];
  expected = @"x";
  for (i = 0; i < 200; i++)
    {
      [m appendString: @"0123456789"];
      expected = [expected stringByAppendingString: @"0123456789"];
    }
  PASS(check(m, expected), "growing after going back to 8-bit characters");
  [m appendString: @"€"];
  expected = [expected stringByAppendingString: @"€"];
  PASS([m smallestEncoding] == NSUnicodeStringEncoding,
    "a euro sign widens it again");
  PASS(check(m, expected), "with the right content");
  [m setString: ascii];
  [m insertString: @"[" atIndex: 0];
  [m replaceCharactersInRange: NSMakeRange(1, 3) withString: @"A"];
  PASS(check(m, [@"[A" stringByAppendingString: [ascii substringFromIndex: 3]]),
    "edits after going back to 8-bit characters a second time");

  /* A string not owning its buffer keeps using it as it is.
   */
  buf = malloc(sizeof(chars));
  memcpy(buf, chars, sizeof(chars));
  m = [[[NSMutableString alloc] initWithCharactersNoCopy: buf length: 4
    freeWhenDone: NO] autorelease];
  [m setString: @"xy"];
  PASS(check(m, @"xy"), "string with a buffer it does not own: right content");
  [m appendString: ascii];
  PASS(check(m, [@"xy" stringByAppendingString: ascii]),
    "and after growing");
  free(buf);

  END_SET("GSMutableString goes back to 8-bit characters")
  return 0;
}
