#if	defined(GNUSTEP_BASE_LIBRARY)
#import <Foundation/Foundation.h>
#import <GNUstepBase/GSMime.h>
#import "Testing.h"

/* When a multipart body arrives across several parse: calls, the parser
 * shifts the unprocessed tail of its buffer down to the start of the
 * buffer.  Source and destination overlap whenever the tail is longer
 * than the part already consumed, so memcpy() must not be used there.
 * Found by fuzzing GSMimeParser (ASan memcpy-param-overlap in
 * -[GSMimeParser(Private) _decodeBody:]).
 */
int main()
{
  START_SET("GSMime multipart buffer shift")

  NSMutableString	*big = [NSMutableString string];
  NSString		*c1;
  NSString		*c2;
  NSString		*c3;
  GSMimeParser		*p = [GSMimeParser mimeParser];
  NSArray		*parts;
  int			i;

  for (i = 0; i < 40; i++)
    {
      [big appendFormat: @"line %02d of the second part\r\n", i];
    }
  c1 = @"MIME-Version: 1.0\r\n"
    @"Content-Type: multipart/mixed; boundary=\"XX\"\r\n\r\n"
    @"--XX\r\nContent-Type: text/plain\r\n\r\nfirst";
  c2 = [NSString stringWithFormat:
    @"\r\n--XX\r\nContent-Type: text/plain\r\n\r\n%@", big];
  c3 = @"end\r\n--XX--\r\n";

  /* Chunk 1 is buffered whole; chunk 2 completes part one and leaves a
   * long, unterminated part two that must be moved to the buffer start.
   */
  PASS([p parse: [c1 dataUsingEncoding: NSASCIIStringEncoding]],
    "parse first chunk")
  PASS([p parse: [c2 dataUsingEncoding: NSASCIIStringEncoding]],
    "parse second chunk")
  [p parse: [c3 dataUsingEncoding: NSASCIIStringEncoding]];
  [p parse: nil];

  parts = [[p mimeDocument] content];
  PASS([parts isKindOfClass: [NSArray class]] && [parts count] == 2,
    "two parts decoded")
  if ([parts count] == 2)
    {
      PASS_EQUAL([[parts objectAtIndex: 0] content], @"first",
	"first part content is correct")
      PASS_EQUAL([[parts objectAtIndex: 1] content],
	[big stringByAppendingString: @"end"],
	"second part content is correct")
    }

  END_SET("GSMime multipart buffer shift")
  return 0;
}
#else
int main(void)
{
  return 0;
}
#endif
