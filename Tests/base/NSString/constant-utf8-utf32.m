#import "Testing.h"
#import <Foundation/NSAutoreleasePool.h>
#import <Foundation/NSException.h>
#import <Foundation/NSString.h>
#include <objc/runtime.h>
#include <string.h>

/* With the new string ABI a constant string's flags give the encoding
 * of its data: 0 ASCII, 1 UTF-8, 2 UTF-16, 3 UTF-32, with nxcslen the
 * length in UTF-16 code units and size the length in bytes.  clang only
 * emits ASCII and UTF-16, so UTF-8 and UTF-32 constant strings are built
 * here by hand, with the layout and class of a real one, and must behave
 * like ordinary strings with the same characters.
 */
#ifdef GNUSTEP_NEW_STRING_ABI
typedef struct {
  Class		isa;
  uint32_t	flags;
  uint32_t	nxcslen;
  uint32_t	size;
  uint32_t	hash;
  const char	*nxcsptr;
} constant;

static NSString *
make(constant *c, uint32_t flags, const void *data, uint32_t size,
  uint32_t length)
{
  c->isa = object_getClass(@"a literal");
  c->flags = flags;
  c->nxcslen = length;
  c->size = size;
  c->hash = 0;
  c->nxcsptr = data;
  return (NSString*)(void*)c;
}

static BOOL
behavesLike(NSString *s, NSString *ref)
{
  NSUInteger	len = [ref length];
  unichar	a[64];
  unichar	b[64];
  NSUInteger	i;

  if ([s length] != len || len > 64)
    {
      return NO;
    }
  for (i = 0; i < len; i++)
    {
      if ([s characterAtIndex: i] != [ref characterAtIndex: i])
	{
	  return NO;
	}
    }
  [s getCharacters: a range: NSMakeRange(0, len)];
  [ref getCharacters: b range: NSMakeRange(0, len)];
  if (memcmp(a, b, len * sizeof(unichar)) != 0)
    {
      return NO;
    }
  if (len > 2)
    {
      [s getCharacters: a range: NSMakeRange(1, len - 2)];
      if (memcmp(a, b + 1, (len - 2) * sizeof(unichar)) != 0)
	{
	  return NO;
	}
    }
  return strcmp([s UTF8String], [ref UTF8String]) == 0
    && [s isEqual: ref] && [ref isEqual: s] && [s isEqualToString: ref]
    && [s hash] == [ref hash]
    && [s compare: ref] == NSOrderedSame
    && [[s substringFromIndex: 1] isEqual: [ref substringFromIndex: 1]]
    && [[ref stringByAppendingString: s]
      isEqual: [ref stringByAppendingString: ref]];
}
#endif

int main()
{
  START_SET("UTF-8 and UTF-32 constant strings")
#ifdef GNUSTEP_NEW_STRING_ABI
  /* "café ☺ 😀!" : é is 2 UTF-8 bytes, ☺ 3, 😀 4 (a surrogate pair) */
  static const char	utf8[] = "caf\xc3\xa9 \xe2\x98\xba \xf0\x9f\x98\x80!";
  static const uint32_t	utf32[] = {'c', 'a', 'f', 0xe9, ' ', 0x263a, ' ',
    0x1f600, '!', 0};
  static const uint32_t	bad32[] = {'a', 0xd800, 'b', 0};
  constant		c1, c2, c3, c4, c5;
  NSString		*ref;
  NSString		*s;
  NSMutableString	*m;

  ref = [NSString stringWithUTF8String: utf8];
  PASS([ref length] == 10, "reference string has 10 UTF-16 code units");

  s = make(&c1, 1, utf8, strlen(utf8), 10);
  PASS(object_getClass(s) == object_getClass(@"another literal"),
    "made a constant string");
  PASS([s fastestEncoding] == NSUTF8StringEncoding, "it is a UTF-8 one");
  PASS([s characterAtIndex: 3] == 0xe9, "UTF-8: characterAtIndex: counts characters, not bytes");
  PASS([s characterAtIndex: 7] == 0xd83d && [s characterAtIndex: 8] == 0xde00,
    "UTF-8: a character outside the BMP is a surrogate pair");
  PASS(behavesLike(s, ref), "UTF-8 constant string behaves like the same string");
  m = [NSMutableString stringWithString: @"x"];
  [m appendString: s];
  PASS([m isEqual: [@"x" stringByAppendingString: ref]], "UTF-8: can be appended");

  s = make(&c2, 3, utf32, 9 * sizeof(uint32_t), 10);
  PASS([s fastestEncoding] == NSUTF32StringEncoding, "made a UTF-32 one");
  PASS([s characterAtIndex: 3] == 0xe9, "UTF-32: characterAtIndex:");
  PASS([s characterAtIndex: 7] == 0xd83d && [s characterAtIndex: 8] == 0xde00,
    "UTF-32: a character outside the BMP is a surrogate pair");
  PASS(strcmp([s UTF8String], utf8) == 0, "UTF-32: UTF8String");
  PASS(behavesLike(s, ref), "UTF-32 constant string behaves like the same string");

  s = make(&c3, 1, "", 0, 0);
  PASS([s length] == 0 && [s isEqual: @""], "empty UTF-8 constant string");

  s = make(&c4, 1, utf8, strlen(utf8), 9);
  PASS_EXCEPTION([s characterAtIndex: 0], NSInternalInconsistencyException,
    "UTF-8 data not matching the length raises");
  s = make(&c5, 3, bad32, 3 * sizeof(uint32_t), 3);
  PASS_EXCEPTION([s characterAtIndex: 0], NSInternalInconsistencyException,
    "UTF-32 data with a lone surrogate raises");
#else
  SKIP("constant strings have no encoding flags with this runtime ABI")
#endif
  END_SET("UTF-8 and UTF-32 constant strings")
  return 0;
}
