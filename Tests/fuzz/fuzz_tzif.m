/* NSTimeZone: TZif (tzfile) data from an untrusted source. */
#include "fuzz_common.h"

static void
fuzz_one(NSData *data)
{
  NSTimeZone	*tz;
  NSDate	*d;
  int		i;
  static double	when[] = { -1e10, -2208988800.0, 0.0, 1e9, 1.7e9, 4e9, 1e11 };

  tz = [NSTimeZone timeZoneWithName: @"Fuzz/Zone" data: data];
  if (tz == nil)
    return;
  [tz description];
  [tz abbreviation];
  [tz secondsFromGMT];
  [tz isDaylightSavingTime];
  [tz daylightSavingTimeOffset];
  [tz nextDaylightSavingTimeTransition];
  for (i = 0; i < (int)(sizeof(when) / sizeof(*when)); i++)
    {
      d = [NSDate dateWithTimeIntervalSince1970: when[i]];
      [tz secondsFromGMTForDate: d];
      [tz abbreviationForDate: d];
      [tz isDaylightSavingTimeForDate: d];
      [tz daylightSavingTimeOffsetForDate: d];
      [tz nextDaylightSavingTimeTransitionAfterDate: d];
      [tz localizedName: NSTimeZoneNameStyleShortDaylightSaving
		 locale: nil];
    }
  [[[NSCalendarDate alloc] initWithTimeIntervalSinceReferenceDate: 1e8]
    autorelease];
  [[tz data] length];
}
