/* NSURL and NSURLComponents parsing.  The input is split at the first
 * newline into a base URL string and a string relative to it.
 */
#include "fuzz_common.h"

static void
poke(NSURL *u)
{
  if (u == nil) return;
  [u scheme]; [u host]; [u port]; [u user]; [u password];
  [u path]; [u query]; [u fragment]; [u parameterString];
  [u resourceSpecifier]; [u absoluteString]; [u relativePath];
  [u pathComponents]; [u lastPathComponent]; [u pathExtension];
  [u isFileURL]; [u description];
  [[u standardizedURL] absoluteString];
  [[u URLByDeletingLastPathComponent] absoluteString];
  [[u URLByAppendingPathComponent: @"x/y"] absoluteString];
  [[u URLByDeletingPathExtension] absoluteString];
  [[u URLByAppendingPathExtension: @"txt"] absoluteString];
}

static void
fuzz_one(NSData *data)
{
  NSString		*all;
  NSRange		r;
  NSString		*base;
  NSString		*rel;
  NSURL			*b;
  NSURLComponents	*c;

  all = [[[NSString alloc] initWithData: data
			       encoding: NSUTF8StringEncoding] autorelease];
  if (all == nil)
    all = [[[NSString alloc] initWithData: data
				 encoding: NSISOLatin1StringEncoding] autorelease];
  r = [all rangeOfString: @"\n"];
  if (r.length > 0)
    {
      base = [all substringToIndex: r.location];
      rel = [all substringFromIndex: NSMaxRange(r)];
    }
  else
    {
      base = all;
      rel = nil;
    }

  b = [NSURL URLWithString: base];
  poke(b);
  if (rel != nil)
    {
      poke([NSURL URLWithString: rel relativeToURL: b]);
      poke([NSURL URLWithString: rel
		  relativeToURL: [NSURL URLWithString: @"http://u:p@h:8/a/b;p?q#f"]]);
    }

  c = [NSURLComponents componentsWithString: base];
  if (c != nil)
    {
      [c scheme]; [c host]; [c port]; [c user]; [c password];
      [c path]; [c query]; [c fragment]; [c queryItems];
      [c percentEncodedPath]; [c percentEncodedQuery];
      [c percentEncodedHost]; [c percentEncodedFragment];
      [c string];
      poke([c URL]);
      if (rel != nil)
	{
	  NS_DURING
	    [c setPath: rel];
	    [c setQuery: rel];
	    [c setFragment: rel];
	    [c string];
	  NS_HANDLER
	  NS_ENDHANDLER
	}
    }

  [base stringByRemovingPercentEncoding];
  [base stringByAddingPercentEncodingWithAllowedCharacters:
    [NSCharacterSet URLQueryAllowedCharacterSet]];
  poke([NSURL fileURLWithPath: base]);
}
