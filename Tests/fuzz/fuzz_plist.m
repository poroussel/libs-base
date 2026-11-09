/* Property list parser (all formats, autodetected). */
#include "fuzz_common.h"

static void
fuzz_one(NSData *data)
{
  NSPropertyListFormat	fmt;
  NSString		*err = nil;
  id			pl;

  pl = [NSPropertyListSerialization
    propertyListFromData: data
	mutabilityOption: NSPropertyListMutableContainersAndLeaves
		  format: &fmt
	errorDescription: &err];
  if (pl != nil)
    {
      /* Exercise the result so dangling objects are touched. */
      [pl description];
    }
}
