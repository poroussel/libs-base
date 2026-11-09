/* NSPortCoder: decode an incoming Distributed Objects message.  This is
 * what a DO server does with data received from a remote peer.
 */
#include "fuzz_common.h"

static void
fuzz_one(NSData *data)
{
  static NSPort	*port = nil;
  NSPortCoder	*c;
  int		i;

  if (port == nil)
    port = [[NSPort port] retain];
  c = [[NSPortCoder alloc] initWithReceivePort: port
				      sendPort: port
				    components: [NSArray arrayWithObject: data]];
  for (i = 0; i < 8; i++)
    {
      id	o = [c decodeObject];
      [o description];
    }
  [c release];
}
