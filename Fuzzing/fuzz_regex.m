/* NSRegularExpression (GNUstep's wrapper around ICU uregex): pattern on
 * the first line, template on the second, subject string after that.
 * The first byte selects options.
 */
#include "fuzz_common.h"

static void
fuzz_one(NSData *data)
{
  NSString		*s;
  NSArray		*parts;
  NSString		*pat;
  NSString		*tpl;
  NSString		*subj;
  NSRegularExpression	*re;
  NSUInteger		opts;
  NSArray		*matches;
  NSUInteger		i;

  if ([data length] < 1)
    return;
  opts = ((const uint8_t*)[data bytes])[0] & 0x7f;
  s = [[[NSString alloc] initWithData:
    [data subdataWithRange: NSMakeRange(1, [data length] - 1)]
    encoding: NSUTF8StringEncoding] autorelease];
  if (s == nil)
    return;
  parts = [s componentsSeparatedByString: @"\n"];
  pat = [parts objectAtIndex: 0];
  tpl = [parts count] > 1 ? [parts objectAtIndex: 1] : @"<$0>";
  subj = [parts count] > 2
    ? [[parts subarrayWithRange: NSMakeRange(2, [parts count] - 2)]
      componentsJoinedByString: @"\n"]
    : @"abc aXbc 123 été";

  re = [NSRegularExpression regularExpressionWithPattern: pat
						 options: opts
						   error: NULL];
  if (re == nil)
    return;
  [re numberOfCaptureGroups];
  [re pattern];
  [re numberOfMatchesInString: subj options: 0
			range: NSMakeRange(0, [subj length])];
  matches = [re matchesInString: subj options: 0
			  range: NSMakeRange([subj length] / 3,
			    [subj length] - [subj length] / 3)];
  for (i = 0; i < [matches count] && i < 16; i++)
    {
      NSTextCheckingResult	*m = [matches objectAtIndex: i];
      NSUInteger		g;

      for (g = 0; g < [m numberOfRanges]; g++)
	[m rangeAtIndex: g];
      [re replacementStringForResult: m inString: subj offset: 0
			    template: tpl];
    }
  [re firstMatchInString: subj options: NSMatchingAnchored
		   range: NSMakeRange(0, [subj length])];
  [re rangeOfFirstMatchInString: subj options: 0
			  range: NSMakeRange(0, [subj length])];
  [re stringByReplacingMatchesInString: subj options: 0
				 range: NSMakeRange(0, [subj length])
			  withTemplate: tpl];
  [NSRegularExpression escapedTemplateForString: tpl];
  [NSRegularExpression escapedPatternForString: pat];
  [subj rangeOfString: pat options: NSRegularExpressionSearch];
}
