/*
 * NSCalendarDate must handle dates before 0001-01-01 and dates very far
 * from the present without looping (practically) forever.  Previously
 * the year search used unsigned arithmetic and started from abs/366,
 * so any date before year 1 hung, and a date some millions of millions
 * of years away took minutes or hours.  Found by fuzzing the binary
 * property list parser (a date object's -description never returned).
 */
#import <Foundation/Foundation.h>
#import "Testing.h"
#include <unistd.h>

static NSCalendarDate *
gmtDate(NSTimeInterval t)
{
  NSCalendarDate	*d;

  d = [NSCalendarDate dateWithTimeIntervalSinceReferenceDate: t];
  [d setTimeZone: [NSTimeZone timeZoneForSecondsFromGMT: 0]];
  return d;
}

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  NSTimeZone		*gmt = [NSTimeZone timeZoneForSecondsFromGMT: 0];
  NSCalendarDate	*d;
  NSCalendarDate	*e;
  double		huge[] = { 1e15, 3.6893488147419103e19, 7.5e21, -1e15,
    -3.6893488284327469e19, 1.0/0.0, -1.0/0.0 };
  unsigned		i;

  alarm(60);	/* The bug made these tests hang. */

  START_SET("NSCalendarDate extreme dates")

  d = gmtDate(-63113904000.0);
  PASS([d yearOfCommonEra] == 1 && [d monthOfYear] == 1
    && [d dayOfMonth] == 1, "0001-01-01 is still correct")
  PASS([d dayOfWeek] == 1, "0001-01-01 is a Monday")

  d = gmtDate(-63113904000.0 - 3600.0);
  PASS([d yearOfCommonEra] == 0 && [d monthOfYear] == 12
    && [d dayOfMonth] == 31 && [d hourOfDay] == 23,
    "one hour before year 1 is 0000-12-31 23:00")
  PASS([d dayOfWeek] == 0, "0000-12-31 is a Sunday")
  PASS_EQUAL([d descriptionWithCalendarFormat: @"%Y-%m-%d %H:%M:%S"],
    @"0000-12-31 23:00:00", "description of a date before year 1")

  d = [NSCalendarDate dateWithYear: -100 month: 3 day: 1
    hour: 12 minute: 30 second: 15 timeZone: gmt];
  PASS([d yearOfCommonEra] == -100 && [d monthOfYear] == 3
    && [d dayOfMonth] == 1 && [d hourOfDay] == 12 && [d minuteOfHour] == 30
    && [d secondOfMinute] == 15, "year -100 round trips")
  e = [NSCalendarDate dateWithYear: -100 month: 2 day: 28
    hour: 12 minute: 30 second: 15 timeZone: gmt];
  PASS([d timeIntervalSinceDate: e] == 86400.0,
    "year -100 is not a leap year")
  e = [NSCalendarDate dateWithYear: -400 month: 2 day: 29
    hour: 0 minute: 0 second: 0 timeZone: gmt];
  PASS([e monthOfYear] == 2 && [e dayOfMonth] == 29,
    "year -400 is a leap year")

  d = [NSCalendarDate dateWithYear: 2026 month: 11 day: 9
    hour: 1 minute: 2 second: 3 timeZone: gmt];
  PASS_EQUAL([d descriptionWithCalendarFormat: @"%Y-%m-%d %H:%M:%S"],
    @"2026-11-09 01:02:03", "a present day date is unchanged")

  d = [NSCalendarDate dateWithYear: 2000000000 month: 6 day: 15
    hour: 0 minute: 0 second: 0 timeZone: gmt];
  PASS([d yearOfCommonEra] == 2000000000 && [d monthOfYear] == 6
    && [d dayOfMonth] == 15, "year 2000000000 round trips")

  for (i = 0; i < sizeof(huge)/sizeof(*huge); i++)
    {
      d = gmtDate(huge[i]);
      PASS([[d description] length] > 0,
	"description of a date %g seconds from the reference date returns",
	huge[i])
    }

  END_SET("NSCalendarDate extreme dates")

  [arp release];
  return 0;
}
