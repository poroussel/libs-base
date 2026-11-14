/* Standalone driver for the fuzzing harnesses.

   Copyright (C) 2026 Free Software Foundation, Inc.

   Written by:  Philippe Roussel <p.o.roussel@free.fr>

   This file is part of the GNUstep Base Library.

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA.

   Used instead of libFuzzer when the compiler does not provide it (gcc).
   It provides main() and calls the harness's LLVMFuzzerTestOneInput()
   the way libFuzzer does, understanding a subset of its options:

     prog [options] file...      run each file once
     prog [options] dir...       fuzz, starting from the files in dir
     -runs=N                     stop after N fuzzed inputs; with 0, run
                                 each corpus file once and stop
     -max_total_time=S           stop after S seconds
     -max_len=N                  maximum input length (default 4096)
     -timeout=S                  an input running longer is a timeout
     -artifact_prefix=P          reproducers are written to P<kind>-<hash>
     -seed=N                     random seed (default: time and pid)

   Other options (-fork=, -rss_limit_mb=...) are accepted and ignored.
   There is no coverage feedback: inputs are random mutations of the
   corpus files (bit flips, byte changes, insertions, deletions, copies
   and splices), so this finds far less than libFuzzer.  The process
   ends at the first crash, after writing the input that caused it;
   run.sh starts it again.
 */
#include <dirent.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
#include <fcntl.h>

extern int LLVMFuzzerTestOneInput(const uint8_t *data, size_t size);
extern int LLVMFuzzerInitialize(int *argc, char ***argv)
  __attribute__((weak));
/* Provided by the sanitizer runtime (gcc and clang) when it is linked. */
extern void __sanitizer_set_death_callback(void (*callback)(void))
  __attribute__((weak));

typedef struct { uint8_t *bytes; size_t len; } input_t;

static input_t		*corpus = 0;
static size_t		ncorpus = 0;
static const char	*prefix = "./";
static unsigned		timeout = 0;
static const uint8_t	*current = 0;
static size_t		currentLen = 0;
static uint64_t		rng;

static uint64_t
rnd(void)
{
  rng ^= rng << 13;
  rng ^= rng >> 7;
  rng ^= rng << 17;
  return rng;
}

static size_t
below(size_t n)
{
  return n ? (size_t)(rnd() % n) : 0;
}

static void
say(const char *s)
{
  ssize_t	r = write(2, s, strlen(s));

  (void)r;
}

/* Write the current input to <prefix><kind>-<hash>.  Only calls
 * functions which are safe in a signal handler.
 */
static void
save(const char *kind)
{
  char		path[4096];
  size_t	l;
  uint64_t	h = 0xcbf29ce484222325ULL;
  size_t	i;
  int		fd;

  if (current == 0 || prefix == 0)
    return;
  l = strlen(prefix);
  if (l + strlen(kind) + 18 > sizeof(path))
    return;
  for (i = 0; i < currentLen; i++)
    h = (h ^ current[i]) * 0x100000001b3ULL;
  memcpy(path, prefix, l);
  memcpy(path + l, kind, strlen(kind));
  l += strlen(kind);
  path[l++] = '-';
  for (i = 0; i < 16; i++)
    path[l++] = "0123456789abcdef"[(h >> (60 - 4 * i)) & 15];
  path[l] = 0;
  fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0644);
  if (fd >= 0)
    {
      ssize_t	r = write(fd, current, currentLen);

      (void)r;
      close(fd);
      say("==standalone: input written to ");
      say(path);
      say("\n");
    }
}

static void
onDeath(void)
{
  save("crash");
}

static void
onSignal(int sig)
{
  if (sig == SIGALRM)
    {
      say("==ERROR: standalone: timeout\n");
      save("timeout");
      _exit(70);
    }
  say("==ERROR: standalone: deadly signal\n");
  save("crash");
  signal(sig, SIG_DFL);
  raise(sig);
}

/* Handle sig unless something (a sanitizer) already does. */
static void
catch(int sig)
{
  struct sigaction	old;

  if (sigaction(sig, 0, &old) == 0 && old.sa_handler == SIG_DFL
    && !(old.sa_flags & SA_SIGINFO))
    signal(sig, onSignal);
}

static void
run(const uint8_t *bytes, size_t len)
{
  current = bytes;
  currentLen = len;
  if (timeout)
    alarm(timeout);
  LLVMFuzzerTestOneInput(bytes, len);
  if (timeout)
    alarm(0);
  current = 0;
}

static int
readFile(const char *path, input_t *in)
{
  FILE		*f = fopen(path, "rb");
  struct stat	st;

  if (f == 0 || fstat(fileno(f), &st) != 0 || !S_ISREG(st.st_mode))
    {
      if (f) fclose(f);
      return 0;
    }
  in->len = (size_t)st.st_size;
  in->bytes = malloc(in->len ? in->len : 1);
  if (in->bytes == 0 || fread(in->bytes, 1, in->len, f) != in->len)
    {
      fclose(f);
      free(in->bytes);
      return 0;
    }
  fclose(f);
  return 1;
}

static void
addFile(const char *path)
{
  input_t	in;

  if (readFile(path, &in))
    {
      corpus = realloc(corpus, (ncorpus + 1) * sizeof(input_t));
      if (corpus == 0)
	{
	  perror("realloc");
	  exit(1);
	}
      corpus[ncorpus++] = in;
    }
}

static void
addDir(const char *path)
{
  DIR		*d = opendir(path);
  struct dirent	*e;

  if (d == 0)
    {
      perror(path);
      exit(1);
    }
  while ((e = readdir(d)) != 0)
    {
      char	buf[4096];

      if (e->d_name[0] == '.')
	continue;
      snprintf(buf, sizeof(buf), "%s/%s", path, e->d_name);
      addFile(buf);
    }
  closedir(d);
}

/* Replace buf (of length *len, capacity max) by a random mutation. */
static void
mutate(uint8_t *buf, size_t *len, size_t max)
{
  static const uint8_t	special[] = {0, 1, 0x7f, 0x80, 0xff, '0', '9',
    ' ', '\n', '"', '<', '>', '{', '}', '%', '\\', '='};
  size_t		n = 1 + below(8);

  while (n-- > 0)
    {
      size_t	l = *len;
      size_t	pos = below(l);
      size_t	cnt;

      switch (below(8))
	{
	  case 0:	/* flip a bit */
	    if (l) buf[pos] ^= (uint8_t)(1 << below(8));
	    break;
	  case 1:	/* random byte */
	    if (l) buf[pos] = (uint8_t)rnd();
	    break;
	  case 2:	/* special byte */
	    if (l) buf[pos] = special[below(sizeof(special))];
	    break;
	  case 3:	/* insert random bytes */
	    cnt = 1 + below(16);
	    if (l + cnt > max) break;
	    pos = below(l + 1);
	    memmove(buf + pos + cnt, buf + pos, l - pos);
	    while (cnt-- > 0) { buf[pos + cnt] = (uint8_t)rnd(); l++; }
	    break;
	  case 4:	/* delete a range */
	    if (l == 0) break;
	    cnt = 1 + below(l - pos < 32 ? l - pos : 32);
	    memmove(buf + pos, buf + pos + cnt, l - pos - cnt);
	    l -= cnt;
	    break;
	  case 5:	/* duplicate a range */
	    if (l == 0) break;
	    cnt = 1 + below(l - pos < 64 ? l - pos : 64);
	    if (l + cnt > max) break;
	    memmove(buf + pos + cnt, buf + pos, l - pos);
	    l += cnt;
	    break;
	  case 6:	/* copy a range over another place */
	    if (l < 2) break;
	    {
	      size_t	to = below(l);

	      cnt = 1 + below(l - (pos > to ? pos : to));
	      memmove(buf + to, buf + pos, cnt);
	    }
	    break;
	  case 7:	/* splice with another corpus input */
	    if (ncorpus == 0) break;
	    {
	      input_t	*o = &corpus[below(ncorpus)];
	      size_t	from = below(o->len);

	      cnt = o->len - from;
	      pos = below(l + 1);
	      if (pos + cnt > max) cnt = max - pos;
	      memcpy(buf + pos, o->bytes + from, cnt);
	      l = pos + cnt;
	    }
	    break;
	}
      *len = l;
    }
}

static unsigned long
number(const char *arg, const char *name)
{
  return strtoul(arg + strlen(name), 0, 10);
}

int
main(int argc, char **argv)
{
  unsigned long	runs = (unsigned long)-1;
  unsigned long	maxTime = 0;
  size_t	maxLen = 4096;
  uint64_t	seed = (uint64_t)time(0) * 1000003u + (uint64_t)getpid();
  int		dirs = 0;
  int		files = 0;
  int		i;
  time_t	start = time(0);
  time_t	last = start;
  unsigned long	done = 0;
  uint8_t	*buf;

  if (LLVMFuzzerInitialize)
    LLVMFuzzerInitialize(&argc, &argv);
  for (i = 1; i < argc; i++)
    {
      const char	*a = argv[i];
      struct stat	st;

      if (a[0] == '-')
	{
	  if (strncmp(a, "-runs=", 6) == 0) runs = number(a, "-runs=");
	  else if (strncmp(a, "-max_total_time=", 16) == 0)
	    maxTime = number(a, "-max_total_time=");
	  else if (strncmp(a, "-max_len=", 9) == 0)
	    maxLen = number(a, "-max_len=");
	  else if (strncmp(a, "-timeout=", 9) == 0)
	    timeout = (unsigned)number(a, "-timeout=");
	  else if (strncmp(a, "-seed=", 6) == 0) seed = number(a, "-seed=");
	  else if (strncmp(a, "-artifact_prefix=", 17) == 0)
	    prefix = a + 17;
	  continue;
	}
      if (stat(a, &st) == 0 && S_ISDIR(st.st_mode))
	{
	  addDir(a);
	  dirs++;
	}
      else
	{
	  size_t	before = ncorpus;

	  addFile(a);
	  if (ncorpus == before)
	    {
	      fprintf(stderr, "%s: cannot read %s\n", argv[0], a);
	      return 1;
	    }
	  files++;
	}
    }

  rng = seed ? seed : 1;
  /* A sanitizer reports the errors it detects, and the signals it
   * handles, itself, then calls onDeath().  Handle the other signals. */
  if (__sanitizer_set_death_callback)
    __sanitizer_set_death_callback(onDeath);
  signal(SIGALRM, onSignal);
  catch(SIGABRT);
  catch(SIGSEGV);
  catch(SIGBUS);
  catch(SIGILL);
  catch(SIGFPE);

  /* Files only, or -runs=0: run each input once, as libFuzzer does. */
  if ((files > 0 && dirs == 0) || runs == 0)
    {
      size_t	j;

      /* The inputs are files already: do not write reproducers. */
      prefix = 0;
      for (j = 0; j < ncorpus; j++)
	run(corpus[j].bytes, corpus[j].len);
      fprintf(stderr, "#%lu\tDONE   executed %lu inputs\n",
	(unsigned long)ncorpus, (unsigned long)ncorpus);
      return 0;
    }

  fprintf(stderr, "standalone driver (no coverage feedback): %lu corpus"
    " inputs, seed %llu, max_len %lu\n", (unsigned long)ncorpus,
    (unsigned long long)seed, (unsigned long)maxLen);
  buf = malloc(maxLen + 1);
  if (buf == 0)
    {
      perror("malloc");
      return 1;
    }
  while (done < runs)
    {
      size_t	len = 0;
      uint8_t	*copy;
      time_t	now;

      if (ncorpus > 0)
	{
	  input_t	*in = &corpus[below(ncorpus)];

	  len = in->len < maxLen ? in->len : maxLen;
	  memcpy(buf, in->bytes, len);
	}
      mutate(buf, &len, maxLen);
      /* A copy of exactly the right size, so that the sanitizer sees
       * reads past the end of the input. */
      copy = malloc(len ? len : 1);
      memcpy(copy, buf, len);
      run(copy, len);
      free(copy);
      done++;
      if ((done & 255) == 0)
	{
	  now = time(0);
	  if (maxTime && (unsigned long)(now - start) >= maxTime)
	    break;
	  if (now - last >= 10)
	    {
	      fprintf(stderr, "#%lu\tpulse  exec/s: %lu time: %lus\n", done,
		(unsigned long)(done / (now > start ? now - start : 1)),
		(unsigned long)(now - start));
	      last = now;
	    }
	}
    }
  {
    time_t	now = time(0);

    fprintf(stderr, "#%lu\tDONE   exec/s: %lu time: %lus\n", done,
      (unsigned long)(done / (now > start ? now - start : 1)),
      (unsigned long)(now - start));
  }
  free(buf);
  return 0;
}
