/* NSPredicate / NSExpression format parsing (GSPredicateScanner).
 * Arguments come from an array so that format specifiers cannot read
 * missing varargs.  Parsed predicates are printed and re-parsed, and
 * evaluated against a dictionary when that cannot call arbitrary
 * methods (no FUNCTION() and no '@' keys, which reach -valueForKey:).
 */
#include "fuzz_common.h"

static NSArray		*args = nil;
static NSDictionary	*obj = nil;

static void
fuzz_one(NSData *data)
{
  NSString	*s;
  NSPredicate	*p;
  NSExpression	*e;
  BOOL		safe;

  if (args == nil)
    {
      args = [[NSArray alloc] initWithObjects: @"name", @"value",
	[NSNumber numberWithInt: 3], [NSArray arrayWithObjects: @"a", @"b", nil],
	@"x*", nil];
      obj = [[NSDictionary alloc] initWithObjectsAndKeys:
	@"value", @"name",
	[NSNumber numberWithInt: 3], @"n",
	[NSArray arrayWithObjects: @"a", @"b", @"c", nil], @"list",
	[NSDictionary dictionaryWithObject: @"y" forKey: @"x"], @"sub",
	nil];
    }
  s = [[[NSString alloc] initWithData: data
			     encoding: NSUTF8StringEncoding] autorelease];
  if (s == nil)
    return;
  safe = ([s rangeOfString: @"@"].length == 0
    && [s rangeOfString: @"FUNCTION" options: NSCaseInsensitiveSearch].length == 0
    && [s rangeOfString: @"%K"].length == 0
    && [s rangeOfString: @"$"].length == 0);

  NS_DURING
    {
      p = [NSPredicate predicateWithFormat: s argumentArray: args];
      if (p != nil)
	{
	  NSString	*f = [p predicateFormat];

	  NS_DURING
	    [NSPredicate predicateWithFormat: f argumentArray: nil];
	  NS_HANDLER
	  NS_ENDHANDLER
	  if (safe && [f rangeOfString: @"@"].length == 0
	    && [f rangeOfString: @"FUNCTION"].length == 0)
	    {
	      [p evaluateWithObject: obj];
	    }
	}
    }
  NS_HANDLER
  NS_ENDHANDLER

  e = [NSExpression expressionWithFormat: s argumentArray: args];
  [e description];
}
