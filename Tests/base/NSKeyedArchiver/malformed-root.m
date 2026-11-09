/*
 * A keyed archive whose root is not a dictionary, or whose $objects
 * entry is not an array, must be rejected with an exception.  The
 * initialiser used to allocate its object map, raise before
 * initialising it, and then crash in -dealloc while emptying the
 * uninitialised map.  Found by fuzzing NSKeyedUnarchiver (ASan SEGV in
 * GSIArrayRemoveItems called from -[NSKeyedUnarchiver dealloc]).
 */
#import <Foundation/Foundation.h>
#import "Testing.h"

static NSData *
plist(id o)
{
  return [NSPropertyListSerialization dataWithPropertyList: o
    format: NSPropertyListBinaryFormat_v1_0 options: 0 error: NULL];
}

static NSDictionary *
archiveWithObjects(id objects)
{
  return [NSDictionary dictionaryWithObjectsAndKeys:
    @"NSKeyedArchiver", @"$archiver",
    [NSNumber numberWithInt: 100000], @"$version",
    objects, @"$objects",
    [NSDictionary dictionary], @"$top",
    nil];
}

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSArray		*bad;
  NSData		*good;
  NSUInteger		i;

  START_SET("NSKeyedUnarchiver malformed archive structure")

  good = [NSKeyedArchiver archivedDataWithRootObject: @"a keyed archive"];
  PASS_EQUAL([NSKeyedUnarchiver unarchiveObjectWithData: good],
    @"a keyed archive", "valid archive decodes")

  bad = [NSArray arrayWithObjects:
    plist([NSArray arrayWithObject: @"not a dictionary"]),
    plist(@"a string at the root of the archive"),
    plist(archiveWithObjects(@"$objects is a string")),
    plist(archiveWithObjects([NSNumber numberWithInt: 3])),
    plist(archiveWithObjects([NSDictionary dictionaryWithObject: @"v"
							 forKey: @"k"])),
    nil];
  for (i = 0; i < [bad count]; i++)
    {
      id	o = nil;

      PASS_EXCEPTION(o = [NSKeyedUnarchiver unarchiveObjectWithData:
	[bad objectAtIndex: i]], NSInvalidArgumentException,
	"malformed archive %lu raises NSInvalidArgumentException",
	(unsigned long)i)
      PASS(o == nil, "nothing decoded from malformed archive %lu",
	(unsigned long)i)
    }

  END_SET("NSKeyedUnarchiver malformed archive structure")

  [arp release];
  return 0;
}
