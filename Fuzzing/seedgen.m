/* Generate seed corpora for the fuzz harnesses.
 * Usage: seedgen <outdir>   (creates <outdir>/<harness>/ subdirectories)
 */
#import <Foundation/Foundation.h>

static NSString	*outDir;

static void
put(NSString *harness, NSString *name, NSData *d)
{
  NSString	*dir = [outDir stringByAppendingPathComponent: harness];

  if (d == nil) return;
  [[NSFileManager defaultManager] createDirectoryAtPath: dir
			    withIntermediateDirectories: YES
					     attributes: nil
						  error: NULL];
  [d writeToFile: [dir stringByAppendingPathComponent: name] atomically: NO];
}

static NSData *
utf8(NSString *s)
{
  return [s dataUsingEncoding: NSUTF8StringEncoding];
}

int
main(int argc, char **argv)
{
  NSAutoreleasePool	*pool = [NSAutoreleasePool new];
  NSArray		*objs;
  NSUInteger		i;

  outDir = [NSString stringWithUTF8String: argc > 1 ? argv[1] : "corpus"];
  objs = [NSArray arrayWithObjects:
    @"hello",
    [NSString stringWithFormat: @"%C%C caf%C", 0x20ac, 0xd83d, 0xe9],
    [NSNumber numberWithInt: 42],
    [NSNumber numberWithLongLong: -1234567890123LL],
    [NSNumber numberWithUnsignedLongLong: 18446744073709551615ULL],
    [NSNumber numberWithDouble: 3.25],
    [NSNumber numberWithBool: YES],
    [NSDate dateWithTimeIntervalSinceReferenceDate: 1000.5],
    [NSData dataWithBytes: "\x00\x01\x02\xff" length: 4],
    [NSArray arrayWithObjects: @"a", @"b", [NSArray array], nil],
    [NSDictionary dictionaryWithObjectsAndKeys:
      @"v", @"k",
      [NSNumber numberWithInt: 1], @"n",
      [NSArray arrayWithObjects: @"x", [NSDictionary dictionary], nil], @"arr",
      [NSData dataWithBytes: "abc" length: 3], @"data",
      [NSDate date], @"date",
      nil],
    nil];

  for (i = 0; i < [objs count]; i++)
    {
      id	o = [objs objectAtIndex: i];
      NSString	*n = [NSString stringWithFormat: @"%lu", (unsigned long)i];
      NSData	*b;

      b = [NSPropertyListSerialization dataWithPropertyList: o
	format: NSPropertyListBinaryFormat_v1_0 options: 0 error: NULL];
      put(@"fuzz_plist", [n stringByAppendingString: @".bin"], b);
      if ([b length] > 8)
	put(@"fuzz_bplist", n, [b subdataWithRange:
	  NSMakeRange(8, [b length] - 8)]);
      put(@"fuzz_plist", [n stringByAppendingString: @".xml"],
	[NSPropertyListSerialization dataWithPropertyList: o
	format: NSPropertyListXMLFormat_v1_0 options: 0 error: NULL]);
      put(@"fuzz_plist", [n stringByAppendingString: @".gs"],
	[NSPropertyListSerialization dataWithPropertyList: o
	format: NSPropertyListGNUstepFormat options: 0 error: NULL]);
      put(@"fuzz_plist", [n stringByAppendingString: @".ostep"],
	[NSPropertyListSerialization dataWithPropertyList: o
	format: NSPropertyListOpenStepFormat options: 0 error: NULL]);
      put(@"fuzz_plist", [n stringByAppendingString: @".gsbin"],
	[NSPropertyListSerialization dataWithPropertyList: o
	format: NSPropertyListGNUstepBinaryFormat options: 0 error: NULL]);
      put(@"fuzz_xml", n,
	[NSPropertyListSerialization dataWithPropertyList: o
	format: NSPropertyListXMLFormat_v1_0 options: 0 error: NULL]);
      put(@"fuzz_keyed", n, [NSKeyedArchiver archivedDataWithRootObject: o]);
      put(@"fuzz_unarchiver", n, [NSArchiver archivedDataWithRootObject: o]);
      if ([NSJSONSerialization isValidJSONObject: o])
	put(@"fuzz_json", n, [NSJSONSerialization dataWithJSONObject: o
	  options: NSJSONWritingPrettyPrinted error: NULL]);
    }
  /* Archives of a few non-plist classes. */
  put(@"fuzz_keyed", @"set", [NSKeyedArchiver archivedDataWithRootObject:
    [NSSet setWithObjects: @"a", [NSNumber numberWithFloat: 1.5],
    [NSURL URLWithString: @"http://x/y"], [NSNull null], nil]]);
  put(@"fuzz_unarchiver", @"set", [NSArchiver archivedDataWithRootObject:
    [NSSet setWithObjects: @"a", [NSValue valueWithRange: NSMakeRange(1,2)],
    [NSURL URLWithString: @"http://x/y"], [NSNull null], nil]]);

  put(@"fuzz_json", @"s1", utf8(@"[\"\\u00e9\\ud83d\\ude00\\n\", 1e308, -0.5, true, null, {\"a\":[]}]"));
  put(@"fuzz_json", @"s2", utf8(@"\"\\uD800\""));
  put(@"fuzz_json", @"s3", utf8(@"12345678901234567890123"));

  put(@"fuzz_xml", @"ns", utf8(@"<?xml version=\"1.0\"?>\n<!DOCTYPE x [<!ENTITY e \"v\">]>"
    @"<a:r xmlns:a=\"urn:a\" b='1' c=\"&amp;&#x41;&#66;&e;\"><![CDATA[x]]>"
    @"<!-- c --><?pi data?><a:c/>t&lt;</a:r>"));

  put(@"fuzz_mime", @"simple", utf8(@"From: a@b\r\nSubject: =?utf-8?q?h=C3=A9?=\r\n"
    @"Content-Type: text/plain; charset=iso-8859-1\r\n"
    @"Content-Transfer-Encoding: quoted-printable\r\n\r\ncaf=E9 =\r\nx\r\n"));
  put(@"fuzz_mime", @"multipart", utf8(@"MIME-Version: 1.0\r\n"
    @"Content-Type: multipart/mixed; boundary=\"XX\"\r\n\r\npre\r\n--XX\r\n"
    @"Content-Type: text/plain\r\n\r\npart1\r\n--XX\r\n"
    @"Content-Type: application/octet-stream\r\n"
    @"Content-Transfer-Encoding: base64\r\n\r\naGVsbG8gd29ybGQ=\r\n"
    @"--XX\r\nContent-Type: message/rfc822\r\n\r\nSubject: in\r\n\r\nbody\r\n--XX--\r\n"));
  put(@"fuzz_mime", @"http", utf8(@"HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n"
    @"Content-Type: text/html; charset=utf-8\r\n\r\n5\r\nhello\r\n0\r\n\r\n"));
  put(@"fuzz_mime", @"http2", utf8(@"HTTP/1.0 100 Continue\r\n\r\nHTTP/1.0 200 OK\r\n"
    @"Content-Length: 3\r\nSet-Cookie: a=b; path=/\r\n\r\nabc"));

  /* NSPortCoder messages: encode each object with a coder whose
   * components array is empty, then take the encoded data. */
  for (i = 0; i < [objs count]; i++)
    {
      NSPort		*port = [NSPort port];
      NSPortCoder	*c;

      c = [[NSPortCoder alloc] initWithReceivePort: port sendPort: port
	components: nil];
      [c encodeObject: [objs objectAtIndex: i]];
      [c encodeObject: [NSValue valueWithRange: NSMakeRange(3, 4)]];
      {
	/* Strip the space reserved for the port's own header. */
	NSData		*d = [[c performSelector: @selector(_components)]
	  objectAtIndex: 0];
	NSUInteger	r = [port reservedSpaceLength];

	put(@"fuzz_portcoder", [NSString stringWithFormat: @"%lu",
	  (unsigned long)i], [d subdataWithRange:
	  NSMakeRange(r, [d length] - r)]);
      }
      [c release];
    }

  /* Seeds for the string parsers. */
  {
    NSArray	*a;
    NSUInteger	j;

    a = [NSArray arrayWithObjects:
      @"http://user:pw@www.example.com:8080/a/b/c.html;p=1?q=1&r=%20#frag",
      @"https://[::1]:443/x\n../y/./z?a#b",
      @"file:///tmp/a%20b/c.txt\n//host/share",
      @"mailto:someone@example.com\n?subject=hi",
      @"ftp://ftp.example.com/pub/\n;type=i",
      @"http://a/b/c/d;p?q\n../../../g",
      @"//example.com:/path\n#only",
      @"data:text/plain;base64,SGVsbG8=",
      @"relative/path?x=%E2%82%AC", nil];
    for (j = 0; j < [a count]; j++)
      put(@"fuzz_url", [NSString stringWithFormat: @"%lu", (unsigned long)j],
	utf8([a objectAtIndex: j]));

    a = [NSArray arrayWithObjects: @"{var}", @"{+path}/here", @"{#hello}",
      @"X{.list*}", @"{/list,var}", @"{;keys*}", @"{?var,hello,empty}",
      @"{&list}", @"{var:3}{hello:5}", @"http://h/{+path:6}/{?keys*}",
      @"{undef}{n}{null}", @"%7B{var}%7D", nil];
    for (j = 0; j < [a count]; j++)
      put(@"fuzz_uritemplate", [NSString stringWithFormat: @"%lu",
	(unsigned long)j], utf8([a objectAtIndex: j]));

    a = [NSArray arrayWithObjects:
      @"name == 'value' AND n > 2", @"%K == %@", @"name BEGINSWITH[cd] \"va\"",
      @"ANY list IN {'a', 'b'}", @"SUBQUERY(list, $x, $x == 'a').@count > 0",
      @"n BETWEEN {1, 5}", @"name MATCHES 'v.*' OR NOT (n < 1)",
      @"sub.x LIKE[c] %@", @"list[FIRST] == 'a' && list[SIZE] = 3",
      @"FUNCTION(name, 'length') == 5", @"n + 2 * 3 - 1 / 4 ** 2 == $V",
      @"TRUEPREDICATE", @"%@ CONTAINS name", @"list[1] ==[n] 'b'",
      @"0x1F == 31 AND 1e3 > 0.5 AND nil == NULL", nil];
    for (j = 0; j < [a count]; j++)
      put(@"fuzz_predicate", [NSString stringWithFormat: @"%lu",
	(unsigned long)j], utf8([a objectAtIndex: j]));

    a = [NSArray arrayWithObjects: @"aGVsbG8gd29ybGQ=", @"YQ==\r\nYg==",
      @"QUJD REVG\n", @"////", @"0123456789abcdefABCDEF", @"<01 02 0a>",
      @"=", nil];
    for (j = 0; j < [a count]; j++)
      put(@"fuzz_base64", [NSString stringWithFormat: @"%lu",
	(unsigned long)j], utf8([a objectAtIndex: j]));

    for (j = 0; j < 64; j++)
      {
	char	b[] = "\x00\x00hello \xe9t\xe9 \x1b$B\x30\x22\x1b(B \xc3\xa9 \x80\xff";

	b[0] = j;
	b[1] = j * 7;
	put(@"fuzz_encoding", [NSString stringWithFormat: @"%lu",
	  (unsigned long)j], [NSData dataWithBytes: b length: sizeof(b) - 1]);
      }

    a = [NSArray arrayWithObjects:
      @"http://www.example.com/a/b\nSet-Cookie: id=a3fWa; Expires=Wed, 21 Oct 2015 07:28:00 GMT; Path=/; Domain=.example.com; Secure; HttpOnly",
      @"https://x.org/\nSet-Cookie: a=b, c=d; max-age=100; path=/p",
      @"http://h/\nSet-Cookie2: n=\"v\"; Version=1; Port=\"80,8080\"; Comment=\"c\"; CommentURL=\"http://h/c\"; Discard",
      @"http://h:81/\nSet-Cookie: x=\"quoted;value\"; Expires=Thu, 01-Jan-1970 00:00:01 GMT",
      nil];
    for (j = 0; j < [a count]; j++)
      put(@"fuzz_cookie", [NSString stringWithFormat: @"%lu",
	(unsigned long)j], utf8([a objectAtIndex: j]));

    a = [NSArray arrayWithObjects:
      @"HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\n"
	@"Content-Disposition: attachment; filename=\"r\\\"e.txt\"\r\n"
	@"Transfer-Encoding: chunked\r\n\r\n5\r\nhello\r\n0\r\n\r\n",
      @"HTTP/1.1 302 Found\r\nLocation: ../other?x=1\r\nSet-Cookie: s=1; Path=/\r\n"
	@"Content-Length: 0\r\n\r\n",
      @"HTTP/1.1 401 Unauthorized\r\nWWW-Authenticate: Digest realm=\"r@h\", "
	@"qop=\"auth,auth-int\", nonce=\"dcd98b7102dd2f0e8b11d0f600bfb0c093\", "
	@"opaque=\"5ccc069c403ebaf9f0171e9517f40e41\", algorithm=MD5\r\n"
	@"Content-Length: 0\r\n\r\n",
      @"HTTP/1.0 401 No\r\nWWW-Authenticate: Basic realm=\"x\"\r\n\r\n",
      @"HTTP/1.1 100 Continue\r\n\r\nHTTP/1.1 204 No Content\r\n\r\n",
      @"HTTP/1.1 200 OK\r\nContent-Type: multipart/byteranges; boundary=B\r\n\r\n"
	@"--B\r\nContent-Range: bytes 0-1/4\r\n\r\nab\r\n--B--\r\n", nil];
    for (j = 0; j < [a count]; j++)
      put(@"fuzz_http", [NSString stringWithFormat: @"%lu",
	(unsigned long)j], utf8([a objectAtIndex: j]));

  }

  /* NSTimeZone: the zones shipped with the system, if any. */
  {
    NSArray	*zones = [NSArray arrayWithObjects: @"UTC", @"Europe/Paris",
      @"America/New_York", @"Australia/Lord_Howe", @"Asia/Kolkata",
      @"America/Sao_Paulo", @"Pacific/Chatham", @"Africa/Casablanca", nil];
    NSUInteger	j;

    for (j = 0; j < [zones count]; j++)
      {
	NSString	*z = [zones objectAtIndex: j];

	put(@"fuzz_tzif", [z stringByReplacingOccurrencesOfString: @"/"
	  withString: @"_"], [NSData dataWithContentsOfFile:
	  [@"/usr/share/zoneinfo" stringByAppendingPathComponent: z]]);
      }
  }

  /* Seeds for the parsers of program supplied strings. */
  {
    NSArray	*a;
    NSUInteger	j;

    a = [NSArray arrayWithObjects: @"%d %i %u %x %X %o %c %%",
      @"%@ and %s", @"%5.2f|%-10e|%+g|%#a|%E|%G", @"%*d %.*s %-*.*@",
      @"%lld %llu %hhd %hd %ld %zu %td %jd %qd", @"%p %ls %S %C %lc",
      @"%08.3Lf %'d % d", @"plain text, no directives", @"%", @"%-#0+ 12.7@",
      nil];
    for (j = 0; j < [a count]; j++)
      put(@"fuzz_format", [NSString stringWithFormat: @"%lu",
	(unsigned long)j], utf8([a objectAtIndex: j]));

    a = [NSArray arrayWithObjects:
      @"\x01\x02\x03\x07\n  -123 0x1F 3.5e10 abc",
      @"\x40\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0b\n42 -9223372036854775809 18446744073709551616",
      @"\x20\x07\x06\x0b\x10\n1,5 2.25 -0,0 1e-400 inf nan",
      @"\x60\x08\x09\x0b\x0c\n0x1.8p3 -0X.1P-2 ab xyz",
      @"\x01\x0a\x0a\x0a\n123456789012345678901234567890.123456789e-20",
      nil];
    for (j = 0; j < [a count]; j++)
      put(@"fuzz_scanner", [NSString stringWithFormat: @"%lu",
	(unsigned long)j], utf8([a objectAtIndex: j]));

    a = [NSArray arrayWithObjects: @"123.456\n-0.001", @"1e127\n1e-128",
      @"99999999999999999999999999999999999999\n3",
      @"-.5\n0", @"NaN\n1", @"12345678901234567890.1234567890e-40\n7\nx",
      @"0.000000000000000000000000000001\n-1e10", @"3,14\n2,5\nlocale", nil];
    for (j = 0; j < [a count]; j++)
      put(@"fuzz_decimal", [NSString stringWithFormat: @"%lu",
	(unsigned long)j], utf8([a objectAtIndex: j]));

    a = [NSArray arrayWithObjects:
      @"%Y-%m-%d %H:%M:%S %z\n2024-02-29 13:05:09 +0100",
      @"%a, %d %b %Y %I:%M:%S %p %Z\nThu, 29 Feb 2024 01:05:09 PM GMT",
      @"%A %B %e %y %j %F %w %c\nThursday February 29 24 060 123 4",
      @"%x %X %%\n02/29/24 13:05:09 %",
      @"%Y%m%dT%H%M%S%z\n20240229T130509-0800",
      @"%d/%m/%Y %H.%M\n31/12/1999 23.59", @"%G-W%V-%u\n2024-W09-4", nil];
    for (j = 0; j < [a count]; j++)
      put(@"fuzz_calendardate", [NSString stringWithFormat: @"%lu",
	(unsigned long)j], utf8([a objectAtIndex: j]));

    a = [NSArray arrayWithObjects:
      @"\x01(a)(X)?b\n[$1|$2]\nabc aXbc", @"\x01\\w+\n$0$0\nhello world",
      @"\x08^\\d+$\n#\n12\n34\nx5",
      @"\x02(?<n>\\p{L}+)\\s*\n\\$${n}\nété ok",
      @"\x10" @"a.c\n\\\\$1\nabc a\nc", @"\x01(?i)(\\b\\w)(\\w*)\n$2$1\nThe Quick Fox",
      nil];
    for (j = 0; j < [a count]; j++)
      put(@"fuzz_regex", [NSString stringWithFormat: @"%lu",
	(unsigned long)j], utf8([a objectAtIndex: j]));

    {
      NSArray	*sets = [NSArray arrayWithObjects:
	[NSCharacterSet letterCharacterSet],
	[NSCharacterSet whitespaceCharacterSet],
	[NSCharacterSet characterSetWithCharactersInString:
	  [NSString stringWithFormat: @"az%C%C", 0xd83d, 0xde00]],
	[NSCharacterSet characterSetWithRange: NSMakeRange(0x10000, 300)],
	nil];

      for (j = 0; j < [sets count]; j++)
	put(@"fuzz_charset", [NSString stringWithFormat: @"%lu",
	  (unsigned long)j], [[sets objectAtIndex: j] bitmapRepresentation]);
    }
  }

  [pool drain];
  return 0;
}
