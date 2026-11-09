/*
 * GSSelectorTypesMatch() skips structure names by scanning for '=' or
 * '}' and did not stop at the end of the string, so a malformed type
 * such as "{abc" (as found in a crafted NSValue archive) made it read
 * past the end of the buffer.  Found by fuzzing NSUnarchiver (ASan
 * stack-buffer-overflow in GSSelectorTypesMatch called from
 * +[NSValue valueClassWithObjCType:]).
 */
#import <Foundation/Foundation.h>
#import <GNUstepBase/GSObjCRuntime.h>
#import "Testing.h"

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  char			buf[8];

  START_SET("unterminated structure types")

  /* Exactly sized buffers so ASan catches any over-read. */
  memcpy(buf, "{abc", 5);
  PASS(GSSelectorTypesMatch(buf, "{abd") == NO,
    "unterminated structure name does not match")
  PASS(GSSelectorTypesMatch("{x", buf) == NO,
    "unterminated structure name does not match (second argument)")
  PASS(GSSelectorTypesMatch(buf, buf + 0) == YES,
    "identical pointers match")
  memcpy(buf, "{ab", 4);
  PASS(GSSelectorTypesMatch(buf, "{ab") == NO,
    "two unterminated structure names never match")
  PASS(GSSelectorTypesMatch("{_NSRange=QQ}", "{foo=QQ}") == YES,
    "structure names are still ignored")
  PASS(GSSelectorTypesMatch("{_NSRange=QQ}", "{foo=Qq}") == NO,
    "structure layouts are still compared")

  END_SET("unterminated structure types")

  [arp release];
  return 0;
}
