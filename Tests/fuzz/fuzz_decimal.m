/* NSDecimalNumber / NSDecimal: parse two numbers (lines of the input),
 * print them, compare them and do arithmetic, rounding and conversions.
 */
#include "fuzz_common.h"

static void
fuzz_one(NSData *data)
{
  NSString		*s;
  NSArray		*lines;
  NSDecimalNumber	*a;
  NSDecimalNumber	*b;
  NSDecimal		da;
  NSDecimal		db;
  NSDecimal		r;
  NSDictionary		*loc;
  NSRoundingMode	mode;
  short			scale;

  s = [[[NSString alloc] initWithData: data
			     encoding: NSISOLatin1StringEncoding] autorelease];
  lines = [s componentsSeparatedByString: @"\n"];
  loc = [NSDictionary dictionaryWithObjectsAndKeys:
    @",", NSDecimalSeparator, nil];
  a = [NSDecimalNumber decimalNumberWithString: [lines objectAtIndex: 0]];
  b = [NSDecimalNumber decimalNumberWithString:
    [lines count] > 1 ? [lines objectAtIndex: 1] : @"3"
    locale: ([lines count] > 2 ? loc : nil)];
  [a description];
  [b descriptionWithLocale: loc];
  [a doubleValue];
  [a longLongValue];
  [a unsignedLongLongValue];
  [a intValue];
  [a compare: b];
  [a hash];
  [[a stringValue] length];

  da = [a decimalValue];
  db = [b decimalValue];
  mode = [s length] % 4;
  scale = (short)([s length] % 64) - 32;
  NSDecimalCompact(&da);
  NSDecimalString(&da, nil);
  NSDecimalString(&db, loc);
  NSDecimalAdd(&r, &da, &db, mode);
  NSDecimalString(&r, nil);
  NSDecimalSubtract(&r, &da, &db, mode);
  NSDecimalString(&r, nil);
  NSDecimalMultiply(&r, &da, &db, mode);
  NSDecimalString(&r, nil);
  NSDecimalDivide(&r, &da, &db, mode);
  NSDecimalString(&r, nil);
  NSDecimalPower(&r, &da, [s length] % 50, mode);
  NSDecimalString(&r, nil);
  NSDecimalMultiplyByPowerOf10(&r, &da, scale, mode);
  NSDecimalString(&r, nil);
  NSDecimalRound(&r, &da, scale, mode);
  NSDecimalString(&r, nil);
  NSDecimalNormalize(&da, &db, mode);
  NSDecimalCompare(&da, &db);
  NSDecimalIsNotANumber(&r);
  [[NSDecimalNumber decimalNumberWithDecimal: r] doubleValue];
  [NSDecimalNumber decimalNumberWithMantissa: [a unsignedLongLongValue]
    exponent: scale isNegative: (mode & 1)];
}
