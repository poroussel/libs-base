/*
 * -scanDouble: kept the first 19 digits of the mantissa but did not
 * count the digits it dropped before the decimal point, so a number
 * with more than 19 digits came out orders of magnitude too small.
 * It also accumulated the exponent in an int without limit: a long
 * exponent wrapped around ("1e4294967296" gave 1), and a value of
 * INT_MIN stayed negative after negation, so the loop over the table
 * of powers of ten never ended and read past the table.
 * Found by fuzzing (ASan global-buffer-overflow in -scanDouble:, with
 * Tests/fuzz/fuzz_scanner.m).
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include <math.h>

static BOOL
near(double a, double b)
{
  return fabs(a - b) <= fabs(b) * 1e-15;
}

static BOOL
scan(NSString *s, double *d)
{
  NSScanner	*sc = [NSScanner scannerWithString: s];
  BOOL		ok;

  *d = -1.0;
  ok = [sc scanDouble: d];
  if (ok == NO && [sc scanLocation] != 0)
    {
      ok = YES;		// Should not have moved: report as a failure
      *d = NAN;
    }
  return ok;
}

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  double		d;

  START_SET("NSScanner -scanDouble: range")

  PASS(scan(@"12345678901234567890123", &d)
    && near(d, 1.2345678901234567890123e22),
    "a mantissa with more than 19 digits keeps its magnitude")
  PASS(scan(@"-123456789012345678901.5", &d)
    && near(d, -1.234567890123456789015e20),
    "a long mantissa with a decimal point keeps its magnitude")
  PASS(scan(@"0.0000000000000000000000123456789012345678901234", &d)
    && near(d, 1.23456789012345678901234e-23),
    "a long mantissa after leading zeros keeps its magnitude")
  PASS(scan(@"1234567890123456789012345e-10", &d)
    && near(d, 1.234567890123456789012345e14),
    "a long mantissa with an exponent keeps its magnitude")
  PASS(scan(@"1.5e3", &d) && d == 1500.0, "ordinary numbers still scan")

  PASS(scan(@"1e600", &d) == NO, "an exponent above 511 is rejected")
  PASS(scan(@"1e4294967296", &d) == NO,
    "an exponent of 2^32 is rejected, not wrapped to zero")
  PASS(scan(@"1e-4294967297", &d) == NO,
    "an exponent of -(2^32+1) is rejected, not wrapped to -1")
  PASS(scan(@"1e2147483648", &d) == NO,
    "an exponent of 2^31 is rejected")
  PASS(scan(@"5e-99999999999999999999999999", &d) == NO,
    "a very long exponent is rejected")

  END_SET("NSScanner -scanDouble: range")

  [arp release];
  return 0;
}
