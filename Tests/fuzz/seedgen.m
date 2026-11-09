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

  [pool drain];
  return 0;
}
