/* NSKeyedUnarchiver.  The archive is a property list, usually binary. */
#include "fuzz_common.h"

static void
fuzz_one(NSData *data)
{
  id	o = [NSKeyedUnarchiver unarchiveObjectWithData: data];

  [o description];
}
