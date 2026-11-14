/* GNUstep's own (non-libxml2) XML parser, GSSloppyXMLParser, which is
 * also used for XML property lists.
 */
#include "fuzz_common.h"

@interface FuzzXMLDelegate : NSObject
@end
@implementation FuzzXMLDelegate
- (void) parser: (NSXMLParser*)p didStartElement: (NSString*)e
  namespaceURI: (NSString*)n qualifiedName: (NSString*)q
    attributes: (NSDictionary*)a
{ [e length]; [n length]; [q length]; [a description]; }
- (void) parser: (NSXMLParser*)p didEndElement: (NSString*)e
  namespaceURI: (NSString*)n qualifiedName: (NSString*)q
{ [e length]; [n length]; [q length]; }
- (void) parser: (NSXMLParser*)p foundCharacters: (NSString*)s
{ [s length]; }
- (void) parser: (NSXMLParser*)p foundCDATA: (NSData*)d
{ [d length]; }
- (void) parser: (NSXMLParser*)p foundComment: (NSString*)s
{ [s length]; }
- (void) parser: (NSXMLParser*)p foundProcessingInstructionWithTarget: (NSString*)t
	   data: (NSString*)d
{ [t length]; [d length]; }
- (void) parser: (NSXMLParser*)p didStartMappingPrefix: (NSString*)x
	  toURI: (NSString*)u
{ [x length]; [u length]; }
- (void) parser: (NSXMLParser*)p didEndMappingPrefix: (NSString*)x
{ [x length]; }
@end

static void
fuzz_one(NSData *data)
{
  static FuzzXMLDelegate	*del = nil;
  NSXMLParser			*p;

  if (del == nil) del = [FuzzXMLDelegate new];
  p = [[NSClassFromString(@"GSSloppyXMLParser") alloc] initWithData: data];
  [p setDelegate: del];
  [p setShouldProcessNamespaces: ([data length] & 1) ? YES : NO];
  [p setShouldReportNamespacePrefixes: ([data length] & 2) ? YES : NO];
  [p parse];
  [p release];
}
