/* An HTTP response from a server, handled the way NSURLProtocol handles
 * it: GSMimeParser in HTTP mode (fed in chunks), then the status line,
 * NSHTTPURLResponse (MIME type, suggested file name), redirect location,
 * Set-Cookie headers and WWW-Authenticate challenges (GSHTTPAuthentication,
 * which builds Basic and Digest authorisation headers).
 */
#include "fuzz_common.h"
#import <GNUstepBase/GSMime.h>

@interface	NSURLResponse (Private)
- (void) _setHeaders: (id)headers;
- (void) _setStatusCode: (NSInteger)code text: (NSString*)text;
@end

@interface	FuzzHTTPAuthentication : NSObject
+ (id) authenticationWithCredential: (NSURLCredential*)credential
		  inProtectionSpace: (NSURLProtectionSpace*)space;
+ (NSURLProtectionSpace*) protectionSpaceForAuthentication: (NSString*)auth
						requestURL: (NSURL*)URL;
- (NSString*) authorizationForAuthentication: (NSString*)authentication
				      method: (NSString*)method
					path: (NSString*)path;
@end

static void
fuzz_one(NSData *data)
{
  static NSURL		*url = nil;
  static Class		authClass = Nil;
  static NSURLCredential	*cred = nil;
  GSMimeParser		*p;
  GSMimeDocument	*doc;
  GSMimeHeader		*info;
  NSHTTPURLResponse	*r;
  NSUInteger		len = [data length];
  NSUInteger		pos = 0;
  NSUInteger		step;
  NSString		*s;
  NSString		*ct;
  NSString		*st;
  int			status;

  if (url == nil)
    {
      url = [[NSURL alloc] initWithString:
	@"http://user:pass@www.example.com:8080/dir/file.html?q=1"];
      authClass = NSClassFromString(@"GSHTTPAuthentication");
      cred = [[NSURLCredential alloc] initWithUser: @"user"
	password: @"pass" persistence: NSURLCredentialPersistenceNone];
    }

  step = len ? (((const uint8_t*)[data bytes])[0] % 64) + 1 : 1;
  p = AUTORELEASE([GSMimeParser new]);
  [p setIsHttp];
  [p setMultipartAsData: YES];
  while (pos < len)
    {
      NSUInteger	n = (len - pos < step) ? len - pos : step;

      if ([p parse: [data subdataWithRange: NSMakeRange(pos, n)]] == NO)
	break;
      pos += n;
    }
  [p parse: nil];
  doc = [p mimeDocument];

  info = [doc headerNamed: @"http"];
  [[info value] floatValue];
  status = [[info objectForKey: NSHTTPPropertyStatusCodeKey] intValue];
  ct = [doc contentType];
  st = [doc contentSubtype];
  ct = (ct && st) ? [ct stringByAppendingFormat: @"/%@", st] : nil;
  s = [[doc headerNamed: @"content-length"] value];
  r = [[[NSHTTPURLResponse alloc] initWithURL: url
    MIMEType: ct
    expectedContentLength: [s length] ? [s intValue] : -1
    textEncodingName: [[doc headerNamed: @"content-type"]
      parameterForKey: @"charset"]] autorelease];
  [r _setStatusCode: status
	       text: [info objectForKey: NSHTTPPropertyStatusReasonKey]];
  [doc deleteHeaderNamed: @"http"];
  [r _setHeaders: [doc allHeaders]];
  [r allHeaderFields];
  [r suggestedFilename];
  [r MIMEType];
  [r textEncodingName];
  [NSHTTPURLResponse localizedStringForStatusCode: status];

  NS_DURING
    [[[NSURL URLWithString: [[doc headerNamed: @"location"] value]
	     relativeToURL: url] absoluteURL] absoluteString];
  NS_HANDLER
  NS_ENDHANDLER

  NS_DURING
    [NSHTTPCookie cookiesWithResponseHeaderFields: [r allHeaderFields]
					   forURL: url];
  NS_HANDLER
  NS_ENDHANDLER

  s = [[doc headerNamed: @"WWW-Authenticate"] value];
  if (s != nil)
    {
      NSURLProtectionSpace	*space;

      space = [authClass protectionSpaceForAuthentication: s requestURL: url];
      if (space != nil)
	{
	  id	a;

	  a = [authClass authenticationWithCredential: cred
				    inProtectionSpace: space];
	  [a authorizationForAuthentication: s
				     method: @"GET"
				       path: @"/dir/file.html?q=1"];
	  [a authorizationForAuthentication: s
				     method: @"POST"
				       path: @"/dir/file.html?q=1"];
	}
    }
  [[doc content] description];
}
