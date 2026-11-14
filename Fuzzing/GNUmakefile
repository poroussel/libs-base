#
#  Fuzzing harnesses Makefile for GNUstep Base Library.
#
#  Copyright (C) 2026 Free Software Foundation, Inc.
#
#  Written by:	Philippe Roussel <p.o.roussel@free.fr>
#
#  This file is part of the GNUstep Base Library.
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU General Public
#  License as published by the Free Software Foundation; either
#  version 2 of the License, or (at your option) any later version.
#
#  This library is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	 See the GNU
#  General Public License for more details.
#
#  You should have received a copy of the GNU General Public
#  License along with this library; if not, write to the Free
#  Software Foundation, Inc., 31 Milk Street #960789 Boston, MA 02196 USA
#
#  The harnesses are built like any program using gnustep-base: with
#  the compiler and flags of the installed gnustep-make, against the
#  installed gnustep-base (not the one in this source tree).  They are
#  linked with libFuzzer when the compiler provides it (clang), and with
#  standalone.c, a simple mutation fuzzer, otherwise (gcc).
#
#  make                      build every harness
#  make fuzz                 build, then fuzz each harness for fuzztime
#  make replay               run each harness once over its corpus
#  make triage               print a signature for each saved crash input
#
#  Variables (on the command line):
#    fuzzobj=plist,json      the harnesses to build and run (default: all);
#                            names with or without the fuzz_ prefix,
#                            separated by commas or spaces
#    fuzztime=300            seconds to fuzz each harness
#    fuzzargs=...            extra options for the fuzzing engine
#    fuzzengine=standalone   use standalone.c even if libFuzzer is there
#    asan=no                 build without AddressSanitizer
#

ifeq ($(GNUSTEP_MAKEFILES),)
 GNUSTEP_MAKEFILES := $(shell gnustep-config --variable=GNUSTEP_MAKEFILES 2>/dev/null)
  ifeq ($(GNUSTEP_MAKEFILES),)
    $(warning )
    $(warning Unable to obtain GNUSTEP_MAKEFILES setting from gnustep-config!)
    $(warning Perhaps gnustep-make is not properly installed,)
    $(warning so gnustep-config is not in your PATH.)
    $(warning )
    $(warning Your PATH is currently $(PATH))
    $(warning )
  endif
endif

ifeq ($(GNUSTEP_MAKEFILES),)
  $(error You need to set GNUSTEP_MAKEFILES before running this!)
endif

# Use the installed gnustep-base, even when called from the top level
# makefile of the source tree, which points this at its own base.make.
override GNUSTEP_LOCAL_ADDITIONAL_MAKEFILES =

# AddressSanitizer unless 'asan=no' (gnustep-make adds the flags).
ifeq ($(asan),)
  asan = yes
endif

include $(GNUSTEP_MAKEFILES)/common.make

ifeq ($(FND_LIBS),)
  $(error gnustep-base is not installed (no base.make in $(GNUSTEP_MAKEFILES)/Additional): the fuzzing harnesses link to the installed library, so run 'make install' first)
endif

comma := ,
ALL_FUZZERS := $(sort $(basename $(wildcard fuzz_*.m)))
ifeq ($(strip $(fuzzobj)),)
  FUZZERS := $(ALL_FUZZERS)
else
  FUZZERS := $(sort $(addprefix fuzz_,$(patsubst fuzz_%,%,$(subst $(comma), ,$(fuzzobj)))))
  UNKNOWN_FUZZERS := $(filter-out $(ALL_FUZZERS),$(FUZZERS))
  ifneq ($(UNKNOWN_FUZZERS),)
    $(error Unknown fuzzer(s) $(UNKNOWN_FUZZERS); the fuzzers are: $(patsubst fuzz_%,%,$(ALL_FUZZERS)))
  endif
endif

fuzztime ?= 300

# Use libFuzzer if the compiler can link a program with it.  Exported
# so that the check is made once, not again in each instance's make.
ifeq ($(fuzzengine),)
  fuzzengine := $(shell printf 'int LLVMFuzzerTestOneInput(const char *d, unsigned long n) { return 0; }\n' | $(CC) -fsanitize=fuzzer -x c - -o /dev/null >/dev/null 2>&1 && echo libfuzzer || echo standalone)
endif
ifneq ($(filter-out libfuzzer standalone,$(fuzzengine)),)
  $(error fuzzengine must be libfuzzer or standalone)
endif
export fuzzengine

TOOL_NAME = $(FUZZERS) seedgen

# Each harness gets main() from libFuzzer or from standalone.c.  The
# seed generator is a plain program.
$(foreach f,$(FUZZERS),$(eval $(f)_OBJC_FILES = $(f).m))
ifeq ($(fuzzengine),libfuzzer)
  $(foreach f,$(FUZZERS),\
    $(eval $(f)_OBJCFLAGS = -fsanitize=fuzzer-no-link)\
    $(eval $(f)_LDFLAGS = -fsanitize=fuzzer))
else
  $(foreach f,$(FUZZERS),$(eval $(f)_C_FILES = standalone.c))
endif
seedgen_OBJC_FILES = seedgen.m

# Inputs for the character set bitmaps are larger than the default.
fuzz_charset_MAXLEN = 40000

include $(GNUSTEP_MAKEFILES)/tool.make

FUZZ_ENV = FUZZ_BIN="$(abspath $(GNUSTEP_OBJ_DIR))" FUZZ_ARGS="$(fuzzargs)" \
	FUZZ_ENGINE="$(fuzzengine)"

fuzz:: all
	@$(FUZZ_ENV) ./run.sh $(fuzztime) \
	  $(foreach f,$(FUZZERS),$(f)$(if $($(f)_MAXLEN),:$($(f)_MAXLEN)))

replay:: all
	@$(FUZZ_ENV) ./replay.sh $(FUZZERS)

triage::
	@$(FUZZ_ENV) ./triage.sh $(FUZZERS)
