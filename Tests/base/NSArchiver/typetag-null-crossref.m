/*
 * -deserializeTypeTag:andCrossRef:atCursor: is called with a NULL
 * cross-reference pointer when decoding arrays (NSUnarchiver and
 * NSPortCoder -decodeArrayOfObjCType:count:at:).  A malformed archive or
 * Distributed Objects message whose tag byte claims a cross-reference
 * made it write through that NULL pointer.  Found by fuzzing
 * NSUnarchiver (ASan SEGV in -[NSDataStatic
 * deserializeTypeTag:andCrossRef:atCursor:]).
 */
#import <Foundation/Foundation.h>
#import "Testing.h"

/* Replace the array tag in front of the characters of "hello world" with
 * one that also claims an 8-bit cross-reference.
 */
static NSData *
corrupt(NSData *archive)
{
  NSMutableData		*m = AUTORELEASE([archive mutableCopy]);
  unsigned char		*b = [m mutableBytes];
  NSUInteger		l = [m length];
  NSUInteger		i;

  for (i = 0; i + 5 <= l; i++)
    {
      if (b[i] == _GSC_ARY_B && b[i+1] == 0 && b[i+2] == 0
	&& b[i+3] == 0 && b[i+4] == 11)
	{
	  b[i] = _GSC_ARY_B | _GSC_X_1;
	  return m;
	}
    }
  return nil;
}

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSData		*good;
  NSData		*bad;
  unsigned char		tag;
  unsigned int		cursor;
  id			o;

  START_SET("type tags with NULL cross-reference")

  /* Directly on NSData. */
  bad = [NSData dataWithBytes: "\x35\x07" length: 2];
  cursor = 0;
  [bad deserializeTypeTag: &tag andCrossRef: 0 atCursor: &cursor];
  PASS(tag == 0x35 && cursor == 2,
    "NSData skips a cross-reference when none is wanted")
  bad = [NSMutableData dataWithBytes: "\x35\x07" length: 2];
  cursor = 0;
  [bad deserializeTypeTag: &tag andCrossRef: 0 atCursor: &cursor];
  PASS(tag == 0x35 && cursor == 2,
    "NSMutableData skips a cross-reference when none is wanted")

  /* Through NSUnarchiver. */
  good = [NSArchiver archivedDataWithRootObject: @"hello world"];
  PASS_EQUAL([NSUnarchiver unarchiveObjectWithData: good], @"hello world",
    "unmodified archive decodes")
  bad = corrupt(good);
  PASS(bad != nil, "found the array tag to corrupt")
  o = nil;
  PASS_EXCEPTION(o = [NSUnarchiver unarchiveObjectWithData: bad], nil,
    "corrupt array tag in an archive raises an exception")
  PASS(o == nil, "nothing is decoded from the corrupt archive")

  END_SET("type tags with NULL cross-reference")

  [arp release];
  return 0;
}
