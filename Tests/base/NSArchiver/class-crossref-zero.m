/*
 * Entry zero of the class cross-reference table used by NSUnarchiver and
 * NSPortCoder is a placeholder (nil), but a class cross-reference of 0
 * was accepted and the nil entry dereferenced.  Found by fuzzing
 * NSUnarchiver and NSPortCoder (ASan SEGV in mapClassObject() and in
 * -[NSPortCoder decodeValueOfObjCType:at:]).
 */
#import <Foundation/Foundation.h>
#import "Testing.h"

/* The first object is encoded as 0x30 0x01 (object, crossref 1)
 * followed by 0x31 0x01 (class definition, crossref 1).  Turn the class
 * definition into a reference to class crossref 0.
 */
static NSData *
classRefZero(NSData *encoded)
{
  NSMutableData		*m = AUTORELEASE([encoded mutableCopy]);
  unsigned char		*b = [m mutableBytes];
  NSUInteger		l = [m length];
  NSUInteger		i;

  for (i = 0; i + 4 <= l; i++)
    {
      if (b[i] == 0x30 && b[i+1] == 0x01 && b[i+2] == 0x31 && b[i+3] == 0x01)
	{
	  b[i+2] = _GSC_XREF | _GSC_X_1 | _GSC_CLASS;
	  b[i+3] = 0;
	  return m;
	}
    }
  return nil;
}

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSString		*str = @"hello world";
  NSData		*good;
  NSData		*bad;
  id			o;

  START_SET("class crossref zero")

  good = [NSArchiver archivedDataWithRootObject: str];
  bad = classRefZero(good);
  PASS(bad != nil, "made archive with a class crossref of 0")
  o = nil;
  PASS_EXCEPTION(o = [NSUnarchiver unarchiveObjectWithData: bad],
    NSInternalInconsistencyException,
    "NSUnarchiver rejects a class crossref of 0")

  {
    NSPort	*port = [NSPort port];
    NSUInteger	r = [port reservedSpaceLength];
    NSPortCoder	*c;
    NSData	*d;

    c = [[NSPortCoder alloc] initWithReceivePort: port
					sendPort: port
				      components: nil];
    [c encodeObject: str];
    d = [[c performSelector: @selector(_components)] objectAtIndex: 0];
    good = [d subdataWithRange: NSMakeRange(r, [d length] - r)];
    RELEASE(c);
    bad = classRefZero(good);
    PASS(bad != nil, "made message with a class crossref of 0")
    c = [[NSPortCoder alloc] initWithReceivePort: port
					sendPort: port
				      components: [NSArray arrayWithObject: bad]];
    PASS_EXCEPTION(o = [c decodeObject], NSInternalInconsistencyException,
      "NSPortCoder rejects a class crossref of 0")
    RELEASE(c);
  }

  END_SET("class crossref zero")

  [arp release];
  return 0;
}
