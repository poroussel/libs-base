/*
 * -base64EncodedDataWithOptions: with a line length added a line ending
 * after the last line when the encoded text filled it exactly, and the
 * padding characters then overwrote that line ending instead of the
 * last characters of data, so the data did not decode to the original.
 * Found by fuzzing (encode/decode round trip in Tests/fuzz/fuzz_base64.m).
 */
#import <Foundation/Foundation.h>
#import "Testing.h"

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSDataBase64EncodingOptions	opts[] = {
    0,
    NSDataBase64Encoding64CharacterLineLength,
    NSDataBase64Encoding76CharacterLineLength,
    NSDataBase64Encoding64CharacterLineLength
      | NSDataBase64EncodingEndLineWithLineFeed,
    NSDataBase64Encoding76CharacterLineLength
      | NSDataBase64EncodingEndLineWithCarriageReturn,
  };
  unsigned char		bytes[200];
  unsigned		i;
  unsigned		o;
  BOOL			roundTrip = YES;
  BOOL			noTrailer = YES;
  NSString		*s;

  START_SET("base64 encoding at line boundaries")

  for (i = 0; i < sizeof(bytes); i++)
    {
      bytes[i] = (i * 37 + 11) & 0xff;
    }
  for (o = 0; o < sizeof(opts) / sizeof(*opts); o++)
    {
      for (i = 1; i <= sizeof(bytes); i++)
	{
	  NSData	*d = [NSData dataWithBytes: bytes length: i];
	  NSData	*e = [d base64EncodedDataWithOptions: opts[o]];
	  NSData	*r;
	  char		last = ((const char*)[e bytes])[[e length] - 1];

	  r = [[NSData alloc] initWithBase64EncodedData: e
	    options: NSDataBase64DecodingIgnoreUnknownCharacters];
	  if ([r isEqual: d] == NO)
	    {
	      roundTrip = NO;
	    }
	  if (last == '\r' || last == '\n')
	    {
	      noTrailer = NO;
	    }
	  [r release];
	}
    }
  PASS(roundTrip, "encoded data decodes to the original for all lengths")
  PASS(noTrailer, "no line ending after the last line")

  s = [[NSData dataWithBytes: bytes length: 55]
    base64EncodedStringWithOptions: NSDataBase64Encoding76CharacterLineLength];
  PASS([s length] == 76 && [s hasSuffix: @"+02Q=="],
    "55 bytes give one full 76 character line ending in padding")

  END_SET("base64 encoding at line boundaries")

  [arp release];
  return 0;
}
