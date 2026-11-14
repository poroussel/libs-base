/* NSCharacterSet from bitmap data (as stored in archives and the
 * NSCharacterSets resources), and the operations that use the bitmap.
 */
#include "fuzz_common.h"

static void
fuzz_one(NSData *data)
{
  NSCharacterSet	*cs;
  NSMutableCharacterSet	*m;
  NSUInteger		len = [data length];
  const uint8_t		*b = [data bytes];
  unsigned		i;
  UTF32Char		probes[] = { 0, 'a', 0xff, 0x2000, 0xfffe, 0xffff,
    0x10000, 0x1f600, 0x10ffff, 0x110000, 0xffffffff };

  cs = [NSCharacterSet characterSetWithBitmapRepresentation: data];
  for (i = 0; i < sizeof(probes) / sizeof(*probes); i++)
    {
      [cs longCharacterIsMember: probes[i]];
      if (probes[i] < 0x10000)
	[cs characterIsMember: probes[i]];
    }
  for (i = 0; i < 18; i++)
    [cs hasMemberInPlane: i];
  [[cs bitmapRepresentation] length];
  [[cs invertedSet] characterIsMember: 'x'];
  [cs isSupersetOfSet: [NSCharacterSet letterCharacterSet]];
  [cs isEqual: [NSCharacterSet decimalDigitCharacterSet]];
  [cs hash];

  m = [NSMutableCharacterSet characterSetWithBitmapRepresentation: data];
  [m formUnionWithCharacterSet: [NSCharacterSet uppercaseLetterCharacterSet]];
  [m formIntersectionWithCharacterSet: cs];
  if (len >= 8)
    {
      UTF32Char	lo = (b[0] | b[1] << 8 | b[2] << 16) & 0x1fffff;
      UTF32Char	n = (b[4] | b[5] << 8) & 0xffff;

      [m addCharactersInRange: NSMakeRange(lo, n)];
      [m removeCharactersInRange: NSMakeRange(lo / 2, n)];
    }
  [m invert];
  [[m bitmapRepresentation] length];
  [[m copy] release];
  [@"Hello, World 123 é" rangeOfCharacterFromSet: m];
  [[@"a,b;c d" componentsSeparatedByCharactersInSet: m] count];
  [@"  trim me  " stringByTrimmingCharactersInSet: m];
}
