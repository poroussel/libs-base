/*
 * The description of a function expression printed its arguments with
 * the description of the NSArray holding them, which quotes and escapes
 * the description of each argument.  With nested functions, such as the
 * repeated unary minus in "n == ----1" (parsed as nested _chs()
 * functions), the escaping doubled the length of the text at each
 * level, so -predicateFormat took exponential time and memory: a 40
 * byte format string could make a program hang and run out of memory.
 * Found by fuzzing (libFuzzer timeout in Tests/fuzz/fuzz_predicate.m,
 * which prints the parsed predicate).
 */
#import <Foundation/Foundation.h>
#import "Testing.h"

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSMutableString	*f;
  NSPredicate		*p;
  NSExpression		*e;
  NSString		*s;
  NSDictionary		*d;
  int			i;

  START_SET("formatting nested function expressions")

  f = [NSMutableString stringWithString: @"n == "];
  for (i = 0; i < 24; i++)
    {
      [f appendString: @"-"];
    }
  [f appendString: @"3"];
  p = [NSPredicate predicateWithFormat: f];
  s = [p predicateFormat];
  PASS(s != nil && [s length] < 1000,
    "format of deeply nested unary minus has a reasonable length")
  d = [NSDictionary dictionaryWithObject: [NSNumber numberWithInt: 3]
				  forKey: @"n"];
  PASS([p evaluateWithObject: d], "an even number of minus signs cancels out")

  e = [NSExpression expressionForFunction: @"sum:"
    arguments: [NSArray arrayWithObject:
      [NSExpression expressionForConstantValue:
	[NSArray arrayWithObjects: [NSNumber numberWithInt: 1],
	  [NSNumber numberWithInt: 2], nil]]]];
  PASS([[e description] hasPrefix: @"sum:("], "function name is printed")
  PASS([[e expressionValueWithObject: nil context: nil] intValue] == 3,
    "function expression still evaluates")

  e = [NSExpression expressionForFunction: @"max:"
    arguments: [NSArray arrayWithObjects:
      [NSExpression expressionForKeyPath: @"a"],
      [NSExpression expressionForConstantValue:
	[NSNumber numberWithInt: 2]], nil]];
  PASS_EQUAL([e description], @"max:(a, 2)",
    "function arguments are separated by commas")

  END_SET("formatting nested function expressions")

  [arp release];
  return 0;
}
