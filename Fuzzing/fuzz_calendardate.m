/* NSCalendarDate: parse a date string with a calendar format (both from
 * the input: format on the first line, string on the second), and print
 * a date with a calendar format taken from the input.
 */
#include "fuzz_common.h"

static void
fuzz_one(NSData *data)
{
  NSString		*s;
  NSRange		r;
  NSString		*fmt;
  NSString		*str;
  NSCalendarDate	*d;
  NSDictionary		*loc;

  s = [[[NSString alloc] initWithData: data
			     encoding: NSUTF8StringEncoding] autorelease];
  if (s == nil)
    return;
  r = [s rangeOfString: @"\n"];
  if (r.length == 0)
    {
      fmt = s;
      str = s;
    }
  else
    {
      fmt = [s substringToIndex: r.location];
      str = [s substringFromIndex: NSMaxRange(r)];
    }
  loc = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];

  d = [NSCalendarDate dateWithString: str calendarFormat: fmt];
  [d description];
  d = [NSCalendarDate dateWithString: str calendarFormat: fmt locale: loc];
  [d description];
  [NSCalendarDate dateWithString: str
		  calendarFormat: @"%Y-%m-%d %H:%M:%S %z"];
  d = [NSCalendarDate dateWithYear: 2024 month: 2 day: 29 hour: 13
    minute: 5 second: 9 timeZone: [NSTimeZone timeZoneWithName: @"UTC"]];
  [d descriptionWithCalendarFormat: fmt];
  [d descriptionWithCalendarFormat: fmt locale: loc];
  [[NSDate date] descriptionWithCalendarFormat: str
				      timeZone: nil
					locale: nil];
}
