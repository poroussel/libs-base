/*
 * Literal (constant) strings and tiny strings are compared with the
 * concrete string classes without the generic NSString code, in both
 * directions.  Check every combination of receiver and argument against
 * the result for plain copies of the strings, including unequal strings
 * of the same length, other kinds of objects and nil.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"

/* A string class which is not one of the concrete GSString classes.
 */
@interface	CustomString : NSString
{
  NSString	*s;
}
@end
@implementation	CustomString
- (id) initWithString: (NSString*)aString
{
  s = [aString copy];
  return self;
}
- (void) dealloc
{
  [s release];
  [super dealloc];
}
- (NSUInteger) length
{
  return [s length];
}
- (unichar) characterAtIndex: (NSUInteger)i
{
  return [s characterAtIndex: i];
}
@end

static NSString *
chars(NSString *s)
{
  unichar	buf[64];
  NSUInteger	l = [s length];

  [s getCharacters: buf];
  return [NSString stringWithCharacters: buf length: l];
}

/* Different kinds of string holding the same characters as s.
 */
static NSArray *
variants(NSString *s)
{
  NSMutableArray	*a = [NSMutableArray array];
  NSString		*padded;
  const char		*utf8 = [s UTF8String];
  unichar		u[64];
  NSUInteger		l = [s length];
  NSMutableString	*m;

  [a addObject: [NSString stringWithUTF8String: utf8]];
  [a addObject: chars(s)];
  [a addObject: [chars(s) substringFromIndex: 0]];
  padded = [NSString stringWithFormat: @"<<%@>>", chars(s)];
  [a addObject: [padded substringWithRange: NSMakeRange(2, l)]];
  [a addObject: [NSMutableString stringWithString: chars(s)]];
  /* A UTF-16 mutable string holding the same characters.
   */
  m = [NSMutableString stringWithCharacters: (unichar[]){ 0x0411 } length: 1];
  [m setString: chars(s)];
  [a addObject: m];
  [s getCharacters: u];
  [a addObject: [[[NSString alloc] initWithBytes: u
					  length: l * sizeof(unichar)
					encoding: NSUnicodeStringEncoding]
    autorelease]];
  [a addObject: [[[CustomString alloc] initWithString: s] autorelease]];
  return a;
}

static unsigned	errors;

static void
compare(NSString *lit, NSString *other)
{
  BOOL	expect = [chars(lit) isEqual: chars(other)];

  if ([lit isEqual: other] != expect
    || [lit isEqualToString: other] != expect
    || [other isEqual: lit] != expect
    || [other isEqualToString: lit] != expect)
    {
      errors++;
      NSLog(@"wrong result comparing '%@' (%s) and '%@' (%s), expected %d",
	lit, object_getClassName(lit), other, object_getClassName(other),
	expect);
    }
}

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSArray		*lits;
  NSUInteger		i;
  NSUInteger		j;
  NSUInteger		k;

  /* Short ASCII literals may be compiled as tiny strings.
   */
  lits = [NSArray arrayWithObjects:
    @"", @"GET", @"PUT", @"GETS", @"content-type", @"content-typx",
    @"Content-type", @"a longer ASCII literal string",
    @"café", @"cafè", @"cafe", @"5 €", @"5 ₭",
    @"€", nil];

  START_SET("literals compared with other strings")

  errors = 0;
  for (i = 0; i < [lits count]; i++)
    {
      NSString	*lit = [lits objectAtIndex: i];

      for (j = 0; j < [lits count]; j++)
	{
	  NSString	*other = [lits objectAtIndex: j];
	  NSArray	*v = variants(other);

	  compare(lit, other);
	  for (k = 0; k < [v count]; k++)
	    {
	      compare(lit, [v objectAtIndex: k]);
	    }
	}
    }
  PASS(0 == errors, "every comparison gives the expected result")

  END_SET("literals compared with other strings")

  START_SET("literals compared with other objects")

  PASS([@"content-type" isEqual: nil] == NO, "a literal is not equal to nil")
  PASS([@"GET" isEqual: nil] == NO, "a tiny literal is not equal to nil")
  PASS([@"1" isEqual: [NSNumber numberWithInt: 1]] == NO,
    "a literal is not equal to a number")
  PASS([@"content-type" isEqual: [NSNumber numberWithInt: 1]] == NO,
    "a literal is not equal to a small object")
  PASS([@"content-type" isEqual: [NSArray array]] == NO,
    "a literal is not equal to an array")
  PASS(([[NSString stringWithFormat: @"%s", "GET"] isEqual:
    [NSNumber numberWithInt: 3]] == NO), "a string is not equal to a number")
  PASS([@"content-type" isEqual: @"content-type"], "a literal equals itself")

  END_SET("literals compared with other objects")

  [arp release];
  return 0;
}
