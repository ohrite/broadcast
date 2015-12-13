# Copyright (c) 2013 The Native Client Authors. All rights reserved.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

#
# GNU Make based build file.  For details on GNU Make see:
# http://www.gnu.org/software/make/manual/make.html
#

#
# Get pepper directory for toolchain and includes.
#
# If NACL_SDK_ROOT is not set, then assume it can be found three directories up.
#
THIS_MAKEFILE := $(abspath $(lastword $(MAKEFILE_LIST)))
NACL_SDK_ROOT ?= $(abspath $(dir $(THIS_MAKEFILE))../nacl_sdk/pepper_46)

# Project Build flags
WARNINGS := -Wno-c++11-extensions -Wno-long-long -Wall -Wswitch-enum -pedantic -Werror
CXXFLAGS := -pthread -std=gnu++11 -stdlib=libc++ $(WARNINGS) -I$(NACL_SDK_ROOT)/include -Isrc

#
# Compute tool paths
#
GETOS := python $(NACL_SDK_ROOT)/tools/getos.py
OSHELPERS = python $(NACL_SDK_ROOT)/tools/oshelpers.py
NATIVE_ARCH = x86-64
OSNAME := $(shell $(GETOS))
RM := $(OSHELPERS) rm
CP := $(OSHELPERS) cp

PNACL_TC_PATH := $(abspath $(NACL_SDK_ROOT)/toolchain/$(OSNAME)_pnacl)
PNACL_TOOLS_PATH := $(abspath $(NACL_SDK_ROOT)/tools)
PNACL_CXX := $(PNACL_TC_PATH)/bin/pnacl-clang++
PNACL_FINALIZE := $(PNACL_TC_PATH)/bin/pnacl-finalize
PNACL_TRANSLATE := $(PNACL_TC_PATH)/bin/pnacl-translate
PNACL_SEL_LDR := $(PNACL_TC_PATH)/bin/pnacl-translate

LDFLAGS := -lppapi_cpp -lppapi
TEST_LDFLAGS := -lppapi_simple_cpp $(LDFLAGS) -lnacl_io -lgtest
EXEC_FLAGS := -B $(PNACL_TOOLS_PATH)/irt_core_x86_64.nexe

MANIFEST = src/capture/capture.nmf

SOURCES = $(wildcard src/*.cc)
TEST_SOURCES = $(wildcard src/test/*.cc)

OBJECTS = $(SOURCES:.cc=.o)
TEST_OBJECTS = $(TEST_SOURCES:.cc=.o)

INTERMEDIATE = build/capture.bc
TEST_INTERMEDIATE = build/capture_suite.bc

EXECUTABLE = $(INTERMEDIATE:.bc=.pexe)
TEST_EXECUTABLE = $(TEST_INTERMEDIATE:.bc=.nexe)

FINAL_MANIFEST = $(patsubst src/capture/%, dist/%, $(MANIFEST))
FINAL_EXECUTABLE = $(patsubst build/%, dist/%, $(EXECUTABLE))

#
# Disable DOS PATH warning when using Cygwin based tools Windows
#
CYGWIN ?= nodosfilewarning
export CYGWIN

.PHONY: all
all: $(FINAL_EXECUTABLE) $(FINAL_MANIFEST)

$(FINAL_EXECUTABLE): $(EXECUTABLE)
	$(CP) $< $@

$(FINAL_MANIFEST):
	$(CP) $(MANIFEST) $@

test: $(TEST_EXECUTABLE)
	$(PNACL_TOOLS_PATH)/sel_ldr_x86_64 $(EXEC_FLAGS) $(TEST_EXECUTABLE)

$(INTERMEDIATE): src/capture/capture.cc $(OBJECTS)
	$(PNACL_CXX) $^ -o $@ -O2 $(CXXFLAGS) -L$(NACL_SDK_ROOT)/lib/pnacl/Release $(LDFLAGS)

$(TEST_INTERMEDIATE): $(OBJECTS) $(TEST_OBJECTS)
	$(PNACL_CXX) $^ -o $@ -O2 $(CXXFLAGS) -L$(NACL_SDK_ROOT)/lib/pnacl/Release $(TEST_LDFLAGS)

%.o: %.cc
	$(PNACL_CXX) -o $@ $(CXXFLAGS) -c $<

%.pexe: %.bc
	$(PNACL_FINALIZE) -o $@ $<

%.nexe: %.pexe
	$(PNACL_TRANSLATE) -o $@ -arch $(NATIVE_ARCH) $<

test-clean:
	$(RM) $(TEST_OBJECTS)
	$(RM) $(TEST_INTERMEDIATE)
	$(RM) $(TEST_EXECUTABLE)
	$(RM) $(TEST_EXECUTABLE).nexe

clean: test-clean
	$(RM) $(OBJECTS)
	$(RM) $(INTERMEDIATE)
	$(RM) $(EXECUTABLE)
	$(RM) $(FINAL_EXECUTABLE)
	$(RM) $(FINAL_MANIFEST)
