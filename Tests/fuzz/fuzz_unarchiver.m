/* NSUnarchiver (typed stream archive format). */
#include "fuzz_common.h"

static void
fuzz_one(NSData *data)
{
  id	o = [NSUnarchiver unarchiveObjectWithData: data];

  [o description];
}
