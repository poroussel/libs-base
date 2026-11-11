/*
 * GSMutableString copies the characters of literal (constant) strings and
 * tiny strings directly in -replaceCharactersInRange:withString: (and so
 * -appendString:, -insertString:atIndex:, ...) and -setString:.  Check the
 * results against the same edits made with ordinary strings, for 8-bit
 * and UTF-16 mutable strings, and that the string is widened only when
 * needed and its hash is kept up to date.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"

/* A copy of a literal which is neither a literal nor a tiny string.
 */
static NSString *
plain(NSString *s)
{
  unichar	buf[64];
  NSUInteger	l = [s length];

  [s getCharacters: buf];
  return [NSString stringWithCharacters: buf length: l];
}

static NSMutableString *
narrow(void)
{
  return [NSMutableString stringWithFormat: @"%s", "start"];
}

static NSMutableString *
wide(void)
{
  unichar	u[6] = { 's', 't', 'a', 'r', 't', 0x0411 };

  return [NSMutableString stringWithCharacters: u length: 6];
}

static void
edits(NSMutableString *(*make)(void), NSString *lit, const char *kind)
{
  NSMutableString	*m;
  NSMutableString	*r;
  NSString		*p = plain(lit);

  START_SET(kind)

  m = make(); r = make();
  [m appendString: lit]; [r appendString: p];
  PASS_EQUAL(m, r, "append")
  PASS([m hash] == [r hash], "append updates the hash")

  [m insertString: lit atIndex: 2]; [r insertString: p atIndex: 2];
  PASS_EQUAL(m, r, "insert")

  [m replaceCharactersInRange: NSMakeRange(1, 3) withString: lit];
  [r replaceCharactersInRange: NSMakeRange(1, 3) withString: p];
  PASS_EQUAL(m, r, "replace a shorter range")

  [m replaceCharactersInRange: NSMakeRange(0, [m length] - 1) withString: lit];
  [r replaceCharactersInRange: NSMakeRange(0, [r length] - 1) withString: p];
  PASS_EQUAL(m, r, "replace a longer range")

  [m hash];
  [m setString: lit]; [r setString: p];
  PASS_EQUAL(m, r, "setString:")
  PASS([m hash] == [p hash], "setString: updates the hash")

  [m setString: @"0123456789abcdefghijklmnopqrstuvwxyz"];
  [m setString: lit];
  PASS_EQUAL(m, p, "setString: shortens the string")

  END_SET(kind)
}

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSMutableString	*m;
  NSStringEncoding	internal;
  NSString		*tinyLit = @"tiny";
  NSString		*asciiLit = @"an ASCII literal string";
  NSString		*latinLit = @"café crème";
  NSString		*euroLit = @"5 €";

  internal = [narrow() fastestEncoding];
  edits(narrow, tinyLit, "tiny literal into an 8-bit string");
  edits(narrow, asciiLit, "ASCII literal into an 8-bit string");
  edits(narrow, latinLit, "latin1 UTF-16 literal into an 8-bit string");
  edits(narrow, euroLit, "UTF-16 literal into an 8-bit string");
  edits(narrow, @"", "empty literal into an 8-bit string");
  edits(narrow, [NSString stringWithUTF8String: "hello"],
    "tiny string into an 8-bit string");
  edits(wide, tinyLit, "tiny literal into a UTF-16 string");
  edits(wide, asciiLit, "ASCII literal into a UTF-16 string");
  edits(wide, euroLit, "UTF-16 literal into a UTF-16 string");

  START_SET("representation")

  m = narrow();
  [m appendString: asciiLit];
  PASS([m fastestEncoding] == internal, "ASCII literal keeps 8-bit storage")
  [m appendString: euroLit];
  PASS([m fastestEncoding] == NSUnicodeStringEncoding,
    "a literal which does not fit widens the string")
  PASS_EQUAL(m, ([NSString stringWithFormat: @"start%@%@",
    plain(asciiLit), plain(euroLit)]), "and keeps its contents")
  m = narrow();
  [m appendString: latinLit];
  if (NSISOLatin1StringEncoding == internal)
    {
      PASS([m fastestEncoding] == internal,
	"latin1 literal keeps latin1 storage")
    }
  PASS_EQUAL(m, ([@"start" stringByAppendingString: plain(latinLit)]),
    "latin1 literal is appended")
  m = narrow();
  [m deleteCharactersInRange: NSMakeRange(0, 5)];
  [m setString: @""];
  PASS([m length] == 0 && [m hash] == [@"" hash],
    "setString: with an empty literal empties the string")
  PASS_EXCEPTION([narrow() replaceCharactersInRange: NSMakeRange(3, 9)
					  withString: asciiLit],
    NSRangeException, "a bad range is still refused")

  END_SET("representation")

  [arp release];
  return 0;
}
