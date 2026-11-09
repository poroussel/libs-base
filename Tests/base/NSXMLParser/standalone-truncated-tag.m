/*
 * GNUstep's own XML parser (GSStandaloneXMLParser/GSSloppyXMLParser,
 * also used to read XML property lists) must not read beyond the end of
 * its input when the document ends inside a tag such as "x<" or "</".
 * Found by fuzzing (ASan heap-buffer-overflow in
 * -[GSStandaloneXMLParser parse]).
 */
#import <Foundation/Foundation.h>
#import "ObjectTesting.h"

static BOOL
parseBytes(Class c, const char *xml, NSInteger *code)
{
  NSData	*d = [NSData dataWithBytes: xml length: strlen(xml)];
  NSXMLParser	*p = [[c alloc] initWithData: d];
  BOOL		ok;

  ok = [p parse];
  *code = [[p parserError] code];
  RELEASE(p);
  return ok;
}

int
main(int argc, char *argv[])
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  Class			c = NSClassFromString(@"GSSloppyXMLParser");
  NSInteger		code;
  unsigned		i;
  const char		*truncated[] = {
    "<", "x<", "<r>text<", "<r></", "<r><?", "<r><abc", "<r></r", 0
  };

  START_SET("GSStandaloneXMLParser truncated tags")

  if (c == Nil)
    SKIP("GSSloppyXMLParser not available")

  PASS(parseBytes(c, "<r><a/>text</r>", &code), "well-formed document parses")

  for (i = 0; truncated[i] != 0; i++)
    {
      PASS(parseBytes(c, truncated[i], &code) == NO,
	"document truncated in a tag (\"%s\") is rejected", truncated[i])
    }
  PASS(parseBytes(c, "<r><abc", &code) == NO
    && code == NSXMLParserPrematureDocumentEndError,
    "truncated tag reports NSXMLParserPrematureDocumentEndError")

  END_SET("GSStandaloneXMLParser truncated tags")

  [arp release];
  return 0;
}
