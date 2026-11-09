/*
 * GSFormat (-initWithFormat: etc.) problems with widths and precisions:
 * - floating point directives (%f %e %g %a) formatted into a stack array
 *   of width + precision + 32 bytes, so a large width such as
 *   "%20000000f" moved the stack pointer far beyond the stack (crash, or
 *   writes into other memory), and the output of large numbers was
 *   silently truncated to 31 characters ("%f" of 1e300);
 * - unknown directives also used a stack array sized by the width;
 * - widths, precisions and argument positions wrapped around when larger
 *   than an int, giving negative sizes.
 * Found by fuzzing (ASan stack-overflow in GSPrivateFormat() and
 * printf_unknown(), with Tests/fuzz/fuzz_format.m).
 */
#import <Foundation/Foundation.h>
#import "Testing.h"

static NSString *
cfmt(const char *fmt, double d)
{
  char	buf[1000];

  snprintf(buf, sizeof(buf), fmt, d);
  return [NSString stringWithUTF8String: buf];
}

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSString		*s;

  START_SET("floating point formats and large widths")

  s = [NSString stringWithFormat: @"%f", 1e300];
  PASS_EQUAL(s, cfmt("%f", 1e300), "%%f of a large number is not truncated")
  s = [NSString stringWithFormat: @"%.0f", -1.5e40];
  PASS_EQUAL(s, cfmt("%.0f", -1.5e40),
    "%%.0f of a large negative number is complete")
  s = [NSString stringWithFormat: @"%.300e", 1.0/3];
  PASS_EQUAL(s, cfmt("%.300e", 1.0/3), "a large precision is honoured")
  s = [NSString stringWithFormat: @"%-12.3a|", 2.5];
  PASS_EQUAL(s, cfmt("%-12.3a|", 2.5), "%%a with width and precision")
  s = [NSString stringWithFormat: @"%8.2f|%g", 3.14159, 0.0001];
  PASS_EQUAL(s, @"    3.14|0.0001",
    "ordinary floating point formats are unchanged")

  PASS_EXCEPTION((s = [NSString stringWithFormat: @"%3000000000d", 5]);,
    NSInvalidArgumentException, "a width larger than an int raises")
  PASS_EXCEPTION((s = [NSString stringWithFormat: @"%.4294967297f", 1.0]);,
    NSInvalidArgumentException, "a precision larger than an int raises")
  PASS_EXCEPTION((s = [NSString stringWithFormat: @"%99999$d", 5]);,
    NSInvalidArgumentException, "a very large argument position raises")

  s = [NSString stringWithFormat: @"%20000000f", 1.5];
  PASS([s length] == 20000000 && [s hasSuffix: @" 1.500000"],
    "a large width on a floating point directive works")
  s = [NSString stringWithFormat: @"%20000000Q", 1.5];
  PASS([s hasPrefix: @"%20000000"],
    "an unknown directive with a large width is printed back")

  END_SET("floating point formats and large widths")

  [arp release];
  return 0;
}
