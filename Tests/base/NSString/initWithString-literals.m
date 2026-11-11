/*
 * -[NSString initWithString:] copies the characters of literal (constant)
 * strings and tiny strings directly, keeping them in 8-bit storage when
 * they fit.  Check the copies, and that they are always new strings of
 * the concrete string classes (never tiny strings): NSScanner relies on
 * that to scan them.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"

static Class	tinyClass;

static NSString *
copyOf(NSString *s)
{
  return AUTORELEASE([[NSString alloc] initWithString: s]);
}

static void
check(NSString *lit, BOOL narrow, const char *kind)
{
  NSString	*c = copyOf(lit);
  NSString	*s = [NSString stringWithString: lit];
  unichar	buf[64];

  START_SET(kind)

  PASS_EQUAL(c, lit, "the copy is equal to the original")
  PASS_EQUAL(s, lit, "+stringWithString: gives an equal string")
  PASS([c length] == [lit length], "the copy has the same length")
  PASS([c hash] == [lit hash], "the copy has the same hash")
  [c getCharacters: buf];
  PASS_EQUAL([NSString stringWithCharacters: buf length: [c length]], lit,
    "the copy has the same characters")
  PASS(narrow == ([c fastestEncoding] != NSUnicodeStringEncoding),
    "the copy uses 8-bit storage only when the characters fit")
  PASS(c != lit && [c class] != tinyClass,
    "the copy is a new string which is not a tiny string")
  PASS([c doubleValue] == [lit doubleValue]
    && [c intValue] == [lit intValue], "the copy can be scanned")
  PASS_EQUAL([c stringByAppendingString: @"!"],
    ([NSString stringWithFormat: @"%@!", lit]), "the copy can be used")

  END_SET(kind)
}

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSString		*tiny = [NSString stringWithUTF8String: "tiny"];
  BOOL			latin1;

  tinyClass = [tiny class];
  latin1 = ([[NSString stringWithFormat: @"%s", "x"] fastestEncoding]
    == NSISOLatin1StringEncoding);

  check(@"an ASCII literal longer than a tiny string", YES, "ASCII literal");
  check(@"GET", YES, "short literal");
  check(@"", YES, "empty literal");
  check(@"12.5", YES, "numeric literal");
  check(@"café crème brûlée", latin1, "latin1 literal");
  check(@"a price in euros: 5 €", NO, "UTF-16 literal");
  check(tiny, YES, "tiny string");
  check([NSString stringWithUTF8String: "-42"], YES, "numeric tiny string");

  START_SET("scanning")

  PASS([@"1.5e3" doubleValue] == 1500.0, "a literal can be scanned")
  PASS([[NSString stringWithUTF8String: "2.5"] doubleValue] == 2.5,
    "a tiny string can be scanned")
  PASS([[NSScanner scannerWithString: tiny] scanString: @"tiny"
					   intoString: NULL],
    "a scanner works on a tiny string")
  PASS_EXCEPTION([[NSString alloc] initWithString: nil],
    NSInvalidArgumentException, "nil is still refused")

  END_SET("scanning")

  [arp release];
  return 0;
}
