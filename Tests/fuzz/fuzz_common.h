/* Shared helpers for the libFuzzer harnesses.  Each harness defines
 * fuzz_one() which is called inside an autorelease pool with any
 * NSException caught (raising an exception on bad input is the
 * documented behaviour and not a bug).
 */
#import <Foundation/Foundation.h>
#include <stdint.h>
#include <stddef.h>

static void fuzz_one(NSData *data);

int
LLVMFuzzerInitialize(int *argc, char ***argv)
{
  /* Keep GNUstep from writing defaults or printing warnings. */
  setenv("GNUSTEP_USER_DEFAULTS_DIR", "/nonexistent", 0);
  return 0;
}

int
LLVMFuzzerTestOneInput(const uint8_t *bytes, size_t size)
{
  NSAutoreleasePool	*pool = [NSAutoreleasePool new];

  NS_DURING
    {
      NSData	*d = [[NSData alloc] initWithBytes: bytes length: size];

      fuzz_one(d);
      [d release];
    }
  NS_HANDLER
    {
    }
  NS_ENDHANDLER
  [pool drain];
  return 0;
}
