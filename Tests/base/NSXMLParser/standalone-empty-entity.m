/*
 * In GNUstep's own XML parser (GSStandaloneXMLParser/GSSloppyXMLParser,
 * also used to read XML property lists) an unquoted attribute value
 * running to the end of the input lost its last character, so for
 * "<r a=&#" the value was "&", the entity after the '&' had length zero,
 * and -_newEntity:length: looked at the '#' beyond the value and called
 * memcpy() with a length of -1.  Found by fuzzing XML property lists
 * (ASan negative-size-param in -[GSStandaloneXMLParser
 * _newEntity:length:]).
 */
#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

@interface AttrHandler : NSObject
{
@public
  NSDictionary	*attrs;
}
@end
@implementation AttrHandler
- (void) parser: (NSXMLParser*)p didStartElement: (NSString*)e
  namespaceURI: (NSString*)n qualifiedName: (NSString*)q
    attributes: (NSDictionary*)a
{
  ASSIGN(attrs, a);
}
- (void) dealloc
{
  RELEASE(attrs);
  [super dealloc];
}
@end

static AttrHandler *
parseBytes(Class c, const char *xml)
{
  NSData	*d = [NSData dataWithBytes: xml length: strlen(xml)];
  NSXMLParser	*p = [[c alloc] initWithData: d];
  AttrHandler	*h = AUTORELEASE([AttrHandler new]);

  [p setDelegate: h];
  [p parse];
  RELEASE(p);
  return h;
}

int
main(int argc, char *argv[])
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  Class			c = NSClassFromString(@"GSSloppyXMLParser");
  AttrHandler		*h;
  unsigned		i;
  const char		*docs[] = {
    "<r a=\"x&\"/>", "<r a=\"&\"/>", "<r a='&'/>", "<r a=\"x&#\"/>",
    "<r a=\"&&&\"/>", "<r a=&#", "<r a=x&#", "<r a=&", 0
  };

  START_SET("GSStandaloneXMLParser empty entity in attribute")

  if (c == Nil)
    SKIP("GSSloppyXMLParser not available")

  h = parseBytes(c, "<r a=\"x&amp;y&#65;\"/>");
  PASS_EQUAL([h->attrs objectForKey: @"a"], @"x&yA",
    "entities in attributes are still decoded")
  h = parseBytes(c, "<r a=abc b=xyz>");
  PASS_EQUAL([h->attrs objectForKey: @"b"], @"xyz",
    "unquoted attribute values are still parsed")

  for (i = 0; docs[i] != 0; i++)
    {
      h = parseBytes(c, docs[i]);
      PASS(YES, "attribute ending with an incomplete entity (%s) is parsed"
	" without crashing", docs[i])
    }

  END_SET("GSStandaloneXMLParser empty entity in attribute")

  [arp release];
  return 0;
}
