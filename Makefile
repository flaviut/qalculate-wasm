.ONESHELL:
SHELL := /bin/bash
.SHELLFLAGS = -ec

ROOT_DIR := $(PWD)
PREFIX := $(ROOT_DIR)/lib/install
CFLAGS := -I$(PREFIX)/include -O3 -flto --profiling
CXXFLAGS = $(CFLAGS) -fno-rtti -fno-exceptions -std=c++11 -DEMSCRIPTEN_HAS_UNBOUND_TYPE_NAMES=0
LDFLAGS := -L$(PREFIX)/lib -flto -fno-rtti -Oz -gseparatedwarf --source-map-base http://localhost:8000

prepend = $(foreach a,$(2),$(1)$(a))
libfiles = $(foreach lib,$(1),$(LIBDIR)/lib$(lib).a)

LIBDIR := lib/install/lib
ALL_LIBS := gmp mpfr xml2 qalculate
ALL_DEPS := $(ALL_LIBS) gnuplot

libreqs = $(call libfiles,$($(1)_REQS))

QALCWASM_LIBS := qalculate gmp mpfr xml2

QALCULATE_VER := 4092c3c900728bb336b3f189dcab531fae33d7f2
QALCULATE_CHKSUM := sha-256=e7724621acd3efddeeb23f0f91a40fb0d9f10de4e7b2e7efae6ae3b09c240c9c
QALCULATE_REQS := gmp mpfr xml2
# QALCULATE_URL = https://github.com/Qalculate/libqalculate/releases/download/v$(1)/libqalculate-$(1).tar.gz
QALCULATE_URL = https://github.com/Qalculate/libqalculate/archive/$(1).tar.gz

EMSDK_VER := 2.0.11
EMSDK_CHKSUM := sha-256=f366c569d10b5eedf56edab86f4e834ca3a5ca0bf4f9ab1818d8575afd10277b
EMSDK_URL = https://github.com/emscripten-core/emsdk/archive/$(1).tar.gz

GMP_VER := 6.2.1
GMP_CHKSUM := sha-256=fd4829912cddd12f84181c3451cc752be224643e87fac497b69edddadc49b4f2
GMP_URL = https://ftp.gnu.org/gnu/gmp/gmp-$(1).tar.xz \

MPFR_VER := 4.1.0
MPFR_CHKSUM := sha-256=0c98a3f1732ff6ca4ea690552079da9c597872d30e96ec28414ee23c95558a7f
MPFR_REQS := gmp
MPFR_URL = https://ftp.gnu.org/gnu/mpfr/mpfr-$(1).tar.xz

XML2_VER := 2.9.12
XML2_CHKSUM := sha-256=c8d6681e38c56f172892c85ddc0852e1fd4b53b4209e7f4ebf17f7e2eae71d92
XML2_URL = http://xmlsoft.org/sources/libxml2-$(1).tar.gz

GNUPLOT_VER := 5.4.1
GNUPLOT_CHKSUM := sha-256=6b690485567eaeb938c26936e5e0681cf70c856d273cc2c45fabf64d8bc6590e
GNUPLOT_URL = https://downloads.sourceforge.net/project/gnuplot/gnuplot/$(1)/gnuplot-$(1).tar.gz

.PHONY: serve default
default: serve

download_tarball = \
    aria2c $(if $($(1)_CHKSUM),--check-integrity=true) --auto-file-renaming=false \
		$(call $(1)_URL,$($(1)_VER)) --out=$@ $(if $($(1)_CHKSUM),--checksum=$($(1)_CHKSUM))
lib/libqalculate.tar.gz:
	$(call download_tarball,QALCULATE)
lib/emsdk.tar.gz:
	$(call download_tarball,EMSDK)
lib/gmp.tar.xz:
	$(call download_tarball,GMP)
lib/mpfr.tar.xz:
	$(call download_tarball,MPFR)
lib/libxml2.tar.gz:
	$(call download_tarball,XML2)
lib/gnuplot.tar.gz:
	$(call download_tarball,GNUPLOT)

untar = tar xmf $< -C $(@D) && rm -rf $@ && mv $@-* $@
lib/emsdk: lib/emsdk.tar.gz
	$(untar)
lib/gmp: lib/gmp.tar.xz
	$(untar)
lib/libqalculate: lib/libqalculate.tar.gz
	$(untar)
lib/mpfr: lib/mpfr.tar.xz
	$(untar)
lib/libxml2: lib/libxml2.tar.gz
	$(untar)
lib/gnuplot: lib/gnuplot.tar.gz
	$(untar)

ACTIVATE_EMSDK := lib/emsdk/upstream/.emsdk_version
EMSDK_ENV := . lib/emsdk/emsdk_env.sh >/dev/null 2>&1

$(ACTIVATE_EMSDK): | lib/emsdk
	$|/emsdk install $(EMSDK_VER)
	$|/emsdk activate $(EMSDK_VER)

CD_BUILDDIR = mkdir -p $(@D) && cd $(@D)
lib/build/libxml2/Makefile: $(ACTIVATE_EMSDK) $(call libreqs,XML2) | lib/libxml2
	$(EMSDK_ENV)
	$(CD_BUILDDIR)
	NOCONFIGURE=true ../../libxml2/autogen.sh
	emconfigure ../../libxml2/configure --host none --prefix="$(PREFIX)" \
	    --with-minimum --with-sax1 --with-tree --with-output
lib/build/gmp/Makefile: $(ACTIVATE_EMSDK) $(call libreqs,GMP) | lib/gmp
	$(EMSDK_ENV)
	$(CD_BUILDDIR)
	emconfigure ../../gmp/configure --host none --prefix="$(PREFIX)" \
		--disable-assembly --disable-cxx --disable-fft \
		--enable-alloca=notreentrant
lib/build/mpfr/Makefile: $(ACTIVATE_EMSDK) $(call libreqs,MPFR) | lib/mpfr
	$(EMSDK_ENV)
	$(CD_BUILDDIR)
	emconfigure ../../mpfr/configure --host none --prefix="$(PREFIX)" \
		--disable-thread-safe --enable-decimal-float=no \
		--with-gmp=$(PREFIX)
lib/build/libqalculate/Makefile: $(ACTIVATE_EMSDK) $(call libreqs,QALCULATE) | lib/libqalculate
	$(EMSDK_ENV)
	$(CD_BUILDDIR)
	[[ -f ../../libqalculate/configure ]] || NOCONFIGURE=true ../../libqalculate/autogen.sh
	CFLAGS="-I$(PREFIX)/include" LDFLAGS="-L$(PREFIX)/lib" \
	LIBXML_CFLAGS="-I$(PREFIX)/include/libxml2" LIBXML_LIBS="$(LDFLAGS)" \
	    emconfigure ../../libqalculate/configure \
	        --build "$$(../../libqalculate/config.guess)" --host none --prefix="$(PREFIX)" \
		    --without-libcurl --without-icu --disable-textport --disable-nls --with-gnuplot-call=byo \
		    --enable-compiled-definitions
lib/build/gnuplot/Makefile: $(ACTIVATE_EMSDK) $(call libreqs,GNUPLOT) | lib/gnuplot
	$(EMSDK_ENV)
	$(CD_BUILDDIR)
	emconfigure ../../gnuplot/configure \
		--host none --prefix="$(PREFIX)" \
		--without-readline --without-x --disable-h3d-quadtree --disable-wxwidgets

submake = $(MAKE) -C $(<D) CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)" LDFLAGS="$(LDFLAGS)"
make_lib = $(submake) install

$(LIBDIR)/libxml2.a: lib/build/libxml2/Makefile
	$(EMSDK_ENV)
	$(make_lib) PROGRAMS=''

$(LIBDIR)/libgmp.a: lib/build/gmp/Makefile
	$(EMSDK_ENV)
	$(make_lib)

$(LIBDIR)/libmpfr.a: lib/build/mpfr/Makefile
	$(EMSDK_ENV)
	$(make_lib)

$(LIBDIR)/libqalculate.a: lib/build/libqalculate/Makefile
	$(EMSDK_ENV)
	$(make_lib)

lib/build/gnuplot/src/gnuplot lib/build/gnuplot/src/gnuplot.wasm &: CFLAGS += -Oz
lib/build/gnuplot/src/gnuplot lib/build/gnuplot/src/gnuplot.wasm &: lib/build/gnuplot/Makefile
	$(EMSDK_ENV)
	$(submake) gnuplot
build/gnuplot.js: lib/build/gnuplot/src/gnuplot
	mkdir -p $(@D) && cp $< $@
build/gnuplot.wasm: lib/build/gnuplot/src/gnuplot.wasm
	mkdir -p $(@D) && cp $< $@

OBJS = $(patsubst src/%.cpp,src/%.o,$(wildcard src/*.cpp))

src/%.o: src/%.cpp $(LIBDIR)/libqalculate.a
	$(EMSDK_ENV)
	emcc --bind $(CXXFLAGS) -Oz -c $< -o $@

build/qalc.js build/qalc.wasm &: $(OBJS) $(call libfiles,$(QALCWASM_LIBS))
	$(EMSDK_ENV)
	mkdir -p $(@D)
	emcc \
	    --bind \
	    $(LDFLAGS) \
	    -s WARN_UNALIGNED=1 -s ERROR_ON_UNDEFINED_SYMBOLS=0 -s FILESYSTEM=0 \
	    $(call prepend,-l,$(QALCWASM_LIBS)) \
	    $(OBJS) \
	    -o build/qalc.js

PUBLIC_FILES = build/qalc.js build/qalc.wasm build/gnuplot.js build/gnuplot.wasm \
               src/index.html src/main.js src/gnuplot-worker.js src/style.css src/favicon.png

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

.PHONY: clean-deps
clean-deps:
	rm -f $(call libfiles,$(ALL_LIBS))
	$(foreach libdir,$(call prepend,lib/build/,$(ALL_LIBS)),[ -d $(libdir) ] && make -C $(libdir) clean
	)@true
