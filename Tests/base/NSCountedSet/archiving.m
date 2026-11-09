/*
 * NSCountedSet stores each object's count as an unsigned int in a
 * non-keyed archive, but the decoder read it into an uninitialised
 * NSUInteger (and the encoder passed an NSUInteger), so on 64-bit
 * systems the counts came back as garbage.  Found while writing tests
 * for the NSUnarchiver fuzzing fixes.
 */
#import <Foundation/Foundation.h>
#import "Testing.h"

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSCountedSet		*s = [NSCountedSet set];
  NSCountedSet		*r;

  START_SET("NSCountedSet archiving")

  [s addObject: @"first string"];
  [s addObject: @"second string"];
  [s addObject: @"second string"];
  [s addObject: @"second string"];

  r = [NSUnarchiver unarchiveObjectWithData:
    [NSArchiver archivedDataWithRootObject: s]];
  PASS([r countForObject: @"first string"] == 1,
    "count of 1 survives archiving")
  PASS([r countForObject: @"second string"] == 3,
    "count of 3 survives archiving")
  PASS_EQUAL(r, s, "unarchived counted set is equal to the original")

  END_SET("NSCountedSet archiving")

  [arp release];
  return 0;
}
