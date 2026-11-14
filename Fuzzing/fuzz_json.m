/* NSJSONSerialization parser. */
#include "fuzz_common.h"

static void
fuzz_one(NSData *data)
{
  NSError	*err = nil;
  id		obj;

  obj = [NSJSONSerialization JSONObjectWithData: data
					options: NSJSONReadingMutableContainers
						| NSJSONReadingAllowFragments
					  error: &err];
  if (obj != nil && [NSJSONSerialization isValidJSONObject: obj])
    {
      [NSJSONSerialization dataWithJSONObject: obj options: 0 error: &err];
    }
}
