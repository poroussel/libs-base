/* GSMimeParser: parse a complete document (headers, multipart bodies,
 * transfer encodings) in one go and incrementally in small chunks.
 */
#include "fuzz_common.h"
#import <GNUstepBase/GSMime.h>

static void
walk(GSMimeDocument *doc, int depth)
{
  id	c;

  if (doc == nil || depth > 50) return;
  [[doc allHeaders] count];
  c = [doc content];
  if ([c isKindOfClass: [NSArray class]])
    {
      NSEnumerator	*e = [c objectEnumerator];
      id		o;

      while ((o = [e nextObject]) != nil)
	if ([o isKindOfClass: [GSMimeDocument class]]) walk(o, depth + 1);
    }
  else if ([c isKindOfClass: [GSMimeDocument class]])
    walk(c, depth + 1);
  else
    [c description];
}

static void
fuzz_one(NSData *data)
{
  GSMimeParser	*p;
  NSUInteger	len = [data length];
  NSUInteger	pos = 0;
  NSUInteger	step;

  walk([GSMimeParser documentFromData: data], 0);

  /* Incremental parse with a chunk size derived from the input. */
  step = len ? (((const uint8_t*)[data bytes])[0] % 17) + 1 : 1;
  p = [GSMimeParser new];
  if (len > 1 && (((const uint8_t*)[data bytes])[1] & 1))
    [p setIsHttp];
  while (pos < len)
    {
      NSUInteger	n = (len - pos < step) ? len - pos : step;

      if ([p parse: [data subdataWithRange: NSMakeRange(pos, n)]] == NO)
	break;
      pos += n;
    }
  [p parse: nil];
  walk([p mimeDocument], 0);
  [p release];
}
