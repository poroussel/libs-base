/* Binary property list parser: the input is prefixed with the binary
 * plist magic so that every input reaches GSBinaryPLParser.
 */
#include "fuzz_common.h"

static void
fuzz_one(NSData *data)
{
  NSMutableData		*m = [NSMutableData dataWithBytes: "bplist00" length: 8];
  NSPropertyListFormat	fmt;
  NSError		*err = nil;
  id			pl;

  [m appendData: data];
  pl = [NSPropertyListSerialization propertyListWithData: m
						 options: NSPropertyListImmutable
						  format: &fmt
						   error: &err];
  if (pl != nil)
    {
      [pl description];
    }
}
