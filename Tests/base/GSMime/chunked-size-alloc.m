/*
 * GSMimeParser decoding an HTTP body with "Transfer-Encoding: chunked"
 * made its output buffer as large as the size announced in a chunk
 * header, before receiving the data, as soon as more input arrived.
 * A server (or a request body) announcing a huge chunk made the
 * client allocate that much memory: "FFFFFFFF" (the largest size that
 * fits in the parser's 8 digit buffer) asked for 4GB, zero filled, so
 * the program was killed for lack of memory.  The test uses 768MB.
 * Found by fuzzing (libFuzzer out-of-memory in -[GSMimeParser
 * decodeData:fromRange:intoData:withContext:], Tests/fuzz/fuzz_http.m).
 */
#import <Foundation/Foundation.h>
#import <GNUstepBase/GSMime.h>
#import "Testing.h"
#include <unistd.h>

/* Virtual memory size of the process in MB, or -1 if unknown. */
static long
vmSizeMB(void)
{
  FILE	*f = fopen("/proc/self/statm", "r");
  long	pages = -1;

  if (f != NULL)
    {
      if (fscanf(f, "%ld", &pages) != 1)
	{
	  pages = -1;
	}
      fclose(f);
    }
  return (pages < 0) ? -1 : pages * (sysconf(_SC_PAGESIZE) / 1024) / 1024;
}

static NSData *
d(const char *s)
{
  return [NSData dataWithBytes: s length: strlen(s)];
}

int main()
{
  NSAutoreleasePool	*arp = [NSAutoreleasePool new];
  GSMimeParser		*p;
  BOOL			ok = NO;
  long			before;

  START_SET("chunked transfer encoding with huge chunk sizes")

  before = vmSizeMB();
  p = AUTORELEASE([GSMimeParser new]);
  [p setIsHttp];
  NS_DURING
    {
      [p parse: d("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n"
	"30000000\r\nhel")];
      [p parse: d("lo")];
      [p parse: d(" world")];
      ok = YES;
    }
  NS_HANDLER
    {
      NSLog(@"%@", localException);
    }
  NS_ENDHANDLER
  PASS(ok, "a huge announced chunk size does not raise")
  if (before < 0)
    {
      SKIP("/proc/self/statm not available")
    }
  PASS(vmSizeMB() - before < 512,
    "a huge announced chunk size does not allocate that much memory")
  PASS([[p data] length] == 11, "the data received so far is decoded")
  PASS([[[p data] description] isEqual: [d("hello world") description]],
    "and is correct")

  p = AUTORELEASE([GSMimeParser new]);
  [p setIsHttp];
  [p parse: d("HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\n\r\n"
    "5\r\nhello\r\n6;ext=1\r\n wor")];
  [p parse: d("ld\r\n0\r\n\r\n")];
  PASS([p isComplete], "normal chunked data completes")
  PASS_EQUAL([[p mimeDocument] convertToText], @"hello world",
    "normal chunked data split across parses is decoded")

  END_SET("chunked transfer encoding with huge chunk sizes")

  [arp release];
  return 0;
}
