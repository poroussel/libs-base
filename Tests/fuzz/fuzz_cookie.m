/* NSHTTPCookie: Set-Cookie / Set-Cookie2 header parsing.  The first line
 * of the input is the URL the response came from, every other line is a
 * response header field "Name: value".
 */
#include "fuzz_common.h"

static void
fuzz_one(NSData *data)
{
  NSString		*s;
  NSArray		*lines;
  NSURL			*url;
  NSMutableDictionary	*hdrs;
  NSArray		*cookies;
  NSUInteger		i;

  s = [[[NSString alloc] initWithData: data
			     encoding: NSISOLatin1StringEncoding] autorelease];
  lines = [s componentsSeparatedByString: @"\n"];
  url = [NSURL URLWithString: [lines objectAtIndex: 0]];
  if (url == nil)
    url = [NSURL URLWithString: @"http://www.example.com/a/b"];
  hdrs = [NSMutableDictionary dictionary];
  for (i = 1; i < [lines count]; i++)
    {
      NSString	*l = [lines objectAtIndex: i];
      NSRange	r = [l rangeOfString: @":"];

      if (r.length == 0)
	[hdrs setObject: l forKey: @"Set-Cookie"];
      else
	[hdrs setObject: [l substringFromIndex: NSMaxRange(r)]
		 forKey: [l substringToIndex: r.location]];
    }
  cookies = [NSHTTPCookie cookiesWithResponseHeaderFields: hdrs forURL: url];
  for (i = 0; i < [cookies count]; i++)
    {
      NSHTTPCookie	*c = [cookies objectAtIndex: i];

      [c properties];
      [c description];
      [c expiresDate];
      [c domain];
      [c path];
      [c portList];
      [NSHTTPCookie cookieWithProperties: [c properties]];
    }
  [NSHTTPCookie requestHeaderFieldsWithCookies: cookies];
}
