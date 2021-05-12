.ONESHELL:
SHELL := /bin/bash
.SHELLFLAGS = -ec

ROOT_DIR := $(PWD)
PREFIX := $(ROOT_DIR)/lib/install
CFLAGS := -I$(PREFIX)/include -O3 -flto --profiling
CXXFLAGS := $(CFLAGS) -fno-rtti -fno-exceptions -std=c++11 -DEMSCRIPTEN_HAS_UNBOUND_TYPE_NAMES=0
LDFLAGS := -L$(PREFIX)/lib -flto

prepend = $(foreach a,$(2),$(1)$(a))
libfiles = $(foreach lib,$(1),$(LIBDIR)/lib$(lib).a)

LIBDIR := lib/install/lib
LIBNAMES := gmp mpfr xml2 qalculate
libreqs = $(call libfiles,$($(1)_REQS))

QALCULATE_VER = 3.15.0
QALCULATE_REQS := gmp mpfr xml2

EMSDK_VER = 2.0.11
EMSDK_CHKSUM = sha-256=f366c569d10b5eedf56edab86f4e834ca3a5ca0bf4f9ab1818d8575afd10277b

GMP_VER = 6.2.1
GMP_CHKSUM = sha-256=fd4829912cddd12f84181c3451cc752be224643e87fac497b69edddadc49b4f2

MPFR_VER = 4.1.0
MPFR_CHKSUM = sha-256=0c98a3f1732ff6ca4ea690552079da9c597872d30e96ec28414ee23c95558a7f
MPFR_REQS := gmp

XML2_VER = 2.9.10
XML2_CHKSUM = sha-256=aafee193ffb8fe0c82d4afef6ef91972cbaf5feea100edc2f262750611b4be1f

.PHONY: serve default
default: serve

lib/emsdk.tar.gz:
	aria2c --check-integrity=true --auto-file-renaming=false \
	    https://github.com/emscripten-core/emsdk/archive/$(EMSDK_VER).tar.gz \
	    --out=lib/emsdk.tar.gz \
	    --checksum=$(EMSDK_CHKSUM)
lib/gmp.tar.xz:
	aria2c --check-integrity=true --auto-file-renaming=false \
	    https://ftp.gnu.org/gnu/gmp/gmp-$(GMP_VER).tar.xz \
	    --out=lib/gmp.tar.xz \
	    --checksum=$(GMP_CHKSUM)
lib/mpfr.tar.xz:
	aria2c --check-integrity=true --auto-file-renaming=false \
	    https://ftp.gnu.org/gnu/mpfr/mpfr-$(MPFR_VER).tar.xz \
	    --out=lib/mpfr.tar.xz \
	    --checksum=$(MPFR_CHKSUM)
lib/libxml2.tar.gz:
	aria2c --check-integrity=true --auto-file-renaming=false \
	    http://xmlsoft.org/sources/libxml2-$(XML2_VER).tar.gz \
	    --out=lib/libxml2.tar.gz \
	    --checksum=$(XML2_CHKSUM)

lib/emsdk: lib/emsdk.tar.gz
	pushd lib
	tar xf emsdk.tar.gz
	mv emsdk-* emsdk
	popd
lib/gmp: lib/gmp.tar.xz
	pushd lib
	tar xf gmp.tar.xz
	mv gmp-* gmp
	popd
lib/libqalculate:
	mkdir -p lib
	pushd lib
	git clone https://github.com/Qalculate/libqalculate.git
	cd libqalculate
	git reset --hard v$(QALCULATE_VER)
	popd
lib/mpfr: lib/mpfr.tar.xz
	pushd lib
	tar xf mpfr.tar.xz
	mv mpfr-* mpfr
	popd
lib/libxml2: lib/libxml2.tar.gz
	pushd lib
	tar xf libxml2.tar.gz
	mv libxml2-* libxml2
	popd

ACTIVATE_EMSDK := lib/emsdk/upstream/.emsdk_version
EMSDK_ENV := . lib/emsdk/emsdk_env.sh >/dev/null 2>&1

$(ACTIVATE_EMSDK): | lib/emsdk
	$|/emsdk install $(EMSDK_VER)
	$|/emsdk activate $(EMSDK_VER)

lib/build/libxml2/Makefile: $(ACTIVATE_EMSDK) $(call libreqs,XML2) | lib/libxml2
	$(EMSDK_ENV)
	mkdir -p lib/build/libxml2
	cd lib/build/libxml2
	emconfigure ../../libxml2/configure --host none --prefix="$(PREFIX)" \
	    --with-minimum --with-sax1 --with-tree --with-output
lib/build/gmp/Makefile: $(ACTIVATE_EMSDK) $(call libreqs,GMP) | lib/gmp
	$(EMSDK_ENV)
	mkdir -p lib/build/gmp
	cd lib/build/gmp
	emconfigure ../../gmp/configure --host none --prefix="$(PREFIX)" \
		--disable-assembly --disable-cxx --disable-fft \
		--enable-alloca=notreentrant
lib/build/mpfr/Makefile: $(ACTIVATE_EMSDK) $(call libreqs,MPFR) | lib/mpfr
	$(EMSDK_ENV)
	mkdir -p lib/build/mpfr
	cd lib/build/mpfr
	emconfigure ../../mpfr/configure --host none --prefix="$(PREFIX)" \
		--disable-thread-safe --enable-decimal-float=no \
		--with-gmp=$(PREFIX)
lib/build/libqalculate/Makefile: $(ACTIVATE_EMSDK) $(call libreqs,QALCULATE) | lib/libqalculate
	$(EMSDK_ENV)
	mkdir -p lib/build/libqalculate
	cd lib/build/libqalculate
	NOCONFIGURE=true ../../libqalculate/autogen.sh
	CFLAGS="-I$(PREFIX)/include" LDFLAGS="-L$(PREFIX)/lib" \
	LIBXML_CFLAGS="-I$(PREFIX)/include/libxml2" LIBXML_LIBS="$(LDFLAGS)" \
	    emconfigure ../../libqalculate/configure \
	        --host none --prefix="$(PREFIX)" \
		    --without-libcurl --without-icu --disable-textport --disable-nls --without-gnuplot-call \
		    --enable-compiled-definitions

$(LIBDIR)/libxml2.a: $(ACTIVATE_EMSDK) lib/build/libxml2/Makefile
	$(EMSDK_ENV)
	$(MAKE) -C lib/build/libxml2 CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)" PROGRAMS= install

$(LIBDIR)/libgmp.a: $(ACTIVATE_EMSDK) lib/build/gmp/Makefile
	$(EMSDK_ENV)
	$(MAKE) -C lib/build/gmp CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)" install

$(LIBDIR)/libmpfr.a: $(ACTIVATE_EMSDK) lib/build/mpfr/Makefile
	$(EMSDK_ENV)
	$(MAKE) -C lib/build/mpfr CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)" install

$(LIBDIR)/libqalculate.a: $(ACTIVATE_EMSDK) lib/build/libqalculate/Makefile
	$(EMSDK_ENV)
	$(MAKE) -C lib/build/libqalculate CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)" install

OBJS = $(patsubst src/%.cpp,src/%.o,$(wildcard src/*.cpp))

src/%.o: src/%.cpp $(ACTIVATE_EMSDK) $(LIBDIR)/libqalculate.a
	$(EMSDK_ENV)
	emcc --bind $(CXXFLAGS) -Oz -c $< -o $@

build/qalc.js: $(OBJS) $(call libfiles,$(LIBNAMES))
	$(EMSDK_ENV)
	mkdir -p build
	emcc \
	    --bind -fno-rtti \
	    $(LDFLAGS) \
	    --source-map-base http://localhost:8000 \
	    -Oz -gseparatedwarf \
	    -s WARN_UNALIGNED=1 -s ERROR_ON_UNDEFINED_SYMBOLS=0 -s FILESYSTEM=0 \
	    $(call prepend,-l,$(LIBNAMES)) \
	    $(OBJS) \
	    -o build/qalc.js
build/qalc.wasm: build/qalc.js

PUBLIC_FILES = build/qalc.js build/qalc.wasm src/index.html src/main.js src/favicon.png

serve: deploy
	python3 -m http.server -d public 8000

public.zip: $(PUBLIC_FILES)
	zip -q -u -j $@ $^

.PHONY: deploy
deploy: public.zip
	unzip -q -o -d public $<

.PHONY: clean
clean:
	rm -rf $(OBJS) public/ build/ public.zip
