/* Base64 and hexadecimal decoders: NSData -initWithBase64Encoded...,
 * GSMimeDocument +decodeBase64:, NSData -initWithHexadecimalRepresentation:.
 * Also checks that encoding then decoding gives back the input.
 */
#include "fuzz_common.h"
#import <GNUstepBase/GSMime.h>
#import <GNUstepBase/NSData+GNUstepBase.h>

static void
fuzz_one(NSData *data)
{
  NSString	*s;
  NSData	*d;
  NSData	*e;

  d = [[[NSData alloc] initWithBase64EncodedData: data options: 0]
    autorelease];
  d = [[[NSData alloc] initWithBase64EncodedData: data
    options: NSDataBase64DecodingIgnoreUnknownCharacters] autorelease];
  [GSMimeDocument decodeBase64: data];

  s = [[[NSString alloc] initWithData: data
			     encoding: NSISOLatin1StringEncoding] autorelease];
  [[[NSData alloc] initWithBase64EncodedString: s options: 0] autorelease];
  [[[NSData alloc] initWithBase64EncodedString: s
    options: NSDataBase64DecodingIgnoreUnknownCharacters] autorelease];
  [GSMimeDocument decodeBase64String: s];
  NS_DURING
    [[[NSData alloc] initWithHexadecimalRepresentation: s] autorelease];
  NS_HANDLER
  NS_ENDHANDLER

  /* Round trips must give back the original bytes. */
  e = [data base64EncodedDataWithOptions:
    NSDataBase64Encoding76CharacterLineLength
    | NSDataBase64EncodingEndLineWithCarriageReturn
    | NSDataBase64EncodingEndLineWithLineFeed];
  d = [[[NSData alloc] initWithBase64EncodedData: e
    options: NSDataBase64DecodingIgnoreUnknownCharacters] autorelease];
  if ([d isEqual: data] == NO)
    abort();
  e = [GSMimeDocument encodeBase64: data];
  if ([[GSMimeDocument decodeBase64: e] isEqual: data] == NO)
    abort();
  if ([data length] > 0 && [[[[NSData alloc] initWithHexadecimalRepresentation:
    [data hexadecimalRepresentation]] autorelease] isEqual: data] == NO)
    abort();
}
