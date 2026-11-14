/* GSURITemplate (RFC 6570): parse a template and expand it with a fixed
 * set of variables of every supported kind.
 */
#include "fuzz_common.h"
#import <GNUstepBase/GSURITemplate.h>

static NSDictionary	*vars = nil;

static void
fuzz_one(NSData *data)
{
  NSString	*s;
  GSURITemplate	*t;

  if (vars == nil)
    {
      vars = [[NSDictionary alloc] initWithObjectsAndKeys:
	@"value", @"var",
	@"Hello World!", @"hello",
	@"/foo/bar", @"path",
	@"", @"empty",
	[NSArray arrayWithObjects: @"red", @"green", @"blue", nil], @"list",
	[NSArray array], @"emptylist",
	[NSDictionary dictionaryWithObjectsAndKeys:
	  @";", @"semi", @".", @"dot", @",", @"comma", nil], @"keys",
	[NSNumber numberWithInt: 42], @"n",
	[NSNull null], @"null",
	nil];
    }
  s = [[[NSString alloc] initWithData: data
			     encoding: NSUTF8StringEncoding] autorelease];
  if (s == nil)
    return;
  t = [GSURITemplate templateWithString: s error: NULL];
  if (t != nil)
    {
      [t description];
      [t relativeStringWithVariables: vars error: NULL];
      [t relativeStringWithVariables: [NSDictionary dictionary] error: NULL];
      [t URLWithVariables: vars relativeToURL: nil error: NULL];
      [t URLWithVariables: vars
	    relativeToURL: [NSURL URLWithString: @"http://h/a/"]
		    error: NULL];
    }
}
