ifndef UNAME_S
UNAME_S := $(shell uname -s)
endif

ifndef UNAME_P
UNAME_P := $(shell uname -p)
endif

ifndef UNAME_M
UNAME_M := $(shell uname -m)
endif

WHISPER_SRC := whisper.cpp
CCV := $(shell $(CC) --version | head -n 1)
CXXV := $(shell $(CXX) --version | head -n 1)

# Mac OS + Arm can report x86_64
# ref: https://github.com/ggerganov/whisper.cpp/issues/66#issuecomment-1282546789
ifeq ($(UNAME_S),Darwin)
	ifneq ($(UNAME_P),arm)
		SYSCTL_M := $(shell sysctl -n hw.optional.arm64)
		ifeq ($(SYSCTL_M),1)
			# UNAME_P := arm
			# UNAME_M := arm64
			warn := $(warning Your arch is announced as x86_64, but it seems to actually be ARM64. Not fixing that can lead to bad performance. For more info see: https://github.com/ggerganov/whisper.cpp/issues/66\#issuecomment-1282546789)
		endif
	endif
endif

#
# Compile flags
#

CFLAGS   = -I./$(WHISPER_SRC)             -O3 -DNDEBUG -std=c11 -fPIC 
CXXFLAGS = -I./$(WHISPER_SRC) -I./$(WHISPER_SRC)/examples -O3 -DNDEBUG -std=c++11 -fPIC
LDFLAGS  =

ifeq ($(UNAME_S),Darwin)
	CFLAGS   += -pthread
	CXXFLAGS += -pthread
endif

# Architecture specific
# TODO: probably these flags need to be tweaked on some architectures
#       feel free to update the Makefile for your architecture and send a pull request or issue
ifeq ($(UNAME_M),$(filter $(UNAME_M),x86_64 i686))
	ifeq ($(UNAME_S),Darwin)
		CFLAGS += -mf16c
		AVX1_M := $(shell sysctl machdep.cpu.features)
		ifneq (,$(findstring FMA,$(AVX1_M)))
			CFLAGS += -mfma
		endif
		ifneq (,$(findstring AVX1.0,$(AVX1_M)))
			CFLAGS += -mavx
		endif
		AVX2_M := $(shell sysctl machdep.cpu.leaf7_features)
		ifneq (,$(findstring AVX2,$(AVX2_M)))
			CFLAGS += -mavx2
		endif
	endif
endif
ifndef WHISPER_NO_ACCELERATE
	# Mac M1 - include Accelerate framework
	ifeq ($(UNAME_S),Darwin)
		CFLAGS  += -DGGML_USE_ACCELERATE
		LDFLAGS += -framework Accelerate
	endif
endif

#
# Print build information
#

$(info I whisper.cpp build info: )
$(info I UNAME_S:  $(UNAME_S))
$(info I UNAME_P:  $(UNAME_P))
$(info I UNAME_M:  $(UNAME_M))
$(info I CFLAGS:   $(CFLAGS))
$(info I CXXFLAGS: $(CXXFLAGS))
$(info I LDFLAGS:  $(LDFLAGS))
$(info I CC:       $(CCV))
$(info I CXX:      $(CXXV))
$(info )

default: main

#
# Build library
#

ggml.o: $(WHISPER_SRC)/ggml.c $(WHISPER_SRC)/ggml.h
	$(CC)  $(CFLAGS)   -c $(WHISPER_SRC)/ggml.c -o ${WHISPER_SRC}/ggml.o

whisper.o: $(WHISPER_SRC)/whisper.cpp $(WHISPER_SRC)/whisper.h
	$(CXX) $(CXXFLAGS) -c $(WHISPER_SRC)/whisper.cpp -o $(WHISPER_SRC)/whisper.o

libwhisper.a: $(WHISPER_SRC)/ggml.o $(WHISPER_SRC)/whisper.o
	$(AR) rcs $(WHISPER_SRC)/libwhisper.a $(WHISPER_SRC)/ggml.o $(WHISPER_SRC)/whisper.o

libwhisper.so: $(WHISPER_SRC)/ggml.o $(WHISPER_SRC)/whisper.o
	$(CXX) $(CXXFLAGS) -shared -o $(WHISPER_SRC)/libwhisper.so $(WHISPER_SRC)/ggml.o $(WHISPER_SRC)/whisper.o $(LDFLAGS)

clean:
	rm -f $(WHISPER_SRC)/*.o $(WHISPER_SRC)/main $(WHISPER_SRC)/libwhisper.a $(WHISPER_SRC)/libwhisper.so

#
# Examples
#

CC_SDL=`sdl2-config --cflags --libs`

SRC_COMMON = $(WHISPER_SRC)/examples/common.cpp
SRC_COMMON_SDL = $(WHISPER_SRC)/examples/common-sdl.cpp

main: $(WHISPER_SRC)/examples/main/main.cpp $(SRC_COMMON) $(WHISPER_SRC)/ggml.o $(WHISPER_SRC)/whisper.o
	$(CXX) $(CXXFLAGS) $(WHISPER_SRC)/examples/main/main.cpp $(SRC_COMMON) $(WHISPER_SRC)/ggml.o $(WHISPER_SRC)/whisper.o -o $(WHISPER_SRC)/main $(LDFLAGS)
	$(WHISPER_SRC)/main -h
