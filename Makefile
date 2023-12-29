.ONESHELL:
SHELL := /bin/bash
.SHELLFLAGS = -ec


ifneq ($(RELEASE),)
extra_flags := -g3 -flto -O3
build := build/release
else
extra_flags := -g3 -Og
build := build/debug
endif

ROOT_DIR := $(PWD)
PREFIX := $(ROOT_DIR)/$(build)/install
CFLAGS := -I$(PREFIX)/include $(extra_flags)
CXXFLAGS = $(CFLAGS) -fno-rtti -fno-exceptions -std=c++11 -DEMSCRIPTEN_HAS_UNBOUND_TYPE_NAMES=0
LDFLAGS := -L$(PREFIX)/lib -fno-rtti $(extra_flags) -gsource-map -gseparate-dwarf

prepend = $(foreach a,$(2),$(1)$(a))
libfiles = $(foreach lib,$(1),$(LIBDIR)/lib$(lib).a)

LIBDIR := $(build)/install/lib
ALL_LIBS := gmp mpfr xml2 qalculate
ALL_DEPS := $(ALL_LIBS) gnuplot

libreqs = $(call libfiles,$($(1)_REQS))

QALCWASM_LIBS := qalculate gmp mpfr xml2

QALCULATE_VER := 4.9.0
QALCULATE_CHKSUM := sha-256=6130ed28f7fb8688bccede4f3749b7f75e4a000b8080840794969d21d1c1bf0f
QALCULATE_REQS := gmp mpfr xml2
QALCULATE_URL = https://github.com/Qalculate/libqalculate/releases/download/v$(1)/libqalculate-$(1).tar.gz

EMSDK_VER := 3.1.51
EMSDK_CHKSUM := sha-256=6edeb200c28505db64a1a9f14373ecc3ba3151cebf3d8314895e603561bc61c2
EMSDK_URL = https://github.com/emscripten-core/emsdk/archive/$(1).tar.gz

GMP_VER := 6.3.0
GMP_CHKSUM := sha-256=a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898
GMP_URL = https://ftp.gnu.org/gnu/gmp/gmp-$(1).tar.xz \

MPFR_VER := 4.2.1
MPFR_CHKSUM := sha-256=277807353a6726978996945af13e52829e3abd7a9a5b7fb2793894e18f1fcbb2
MPFR_REQS := gmp
MPFR_URL = https://ftp.gnu.org/gnu/mpfr/mpfr-$(1).tar.xz

XML2_VER := 2.9.12
XML2_CHKSUM := sha-256=c8d6681e38c56f172892c85ddc0852e1fd4b53b4209e7f4ebf17f7e2eae71d92
XML2_URL = http://xmlsoft.org/sources/libxml2-$(1).tar.gz

GNUPLOT_VER := 5.4.10
GNUPLOT_CHKSUM := sha-256=975d8c1cc2c41c7cedc4e323aff035d977feb9a97f0296dd2a8a66d197a5b27c
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
$(build)/libxml2/Makefile: $(ACTIVATE_EMSDK) $(call libreqs,XML2) | lib/libxml2
	$(EMSDK_ENV)
	$(CD_BUILDDIR)
	NOCONFIGURE=true $(ROOT_DIR)/lib/libxml2/autogen.sh
	emconfigure $(ROOT_DIR)/lib/libxml2/configure --host none --prefix="$(PREFIX)" \
	    --with-minimum --with-sax1 --with-tree --with-output
$(build)/gmp/Makefile: $(ACTIVATE_EMSDK) $(call libreqs,GMP) | lib/gmp
	$(EMSDK_ENV)
	$(CD_BUILDDIR)
	emconfigure $(ROOT_DIR)/lib/gmp/configure --host none --prefix="$(PREFIX)" \
		--disable-assembly --disable-cxx --disable-fft \
		--enable-alloca=notreentrant
$(build)/mpfr/Makefile: $(ACTIVATE_EMSDK) $(call libreqs,MPFR) | lib/mpfr
	$(EMSDK_ENV)
	$(CD_BUILDDIR)
	autoreconf -if -Wall $(ROOT_DIR)/lib/mpfr
	emconfigure $(ROOT_DIR)/lib/mpfr/configure --host none --prefix="$(PREFIX)" \
		--disable-thread-safe --enable-decimal-float=no \
		--with-gmp=$(PREFIX)
$(build)/libqalculate/Makefile: $(ACTIVATE_EMSDK) $(call libreqs,QALCULATE) | lib/libqalculate
	$(EMSDK_ENV)
	$(CD_BUILDDIR)
	[[ -f $(ROOT_DIR)/lib/libqalculate/configure ]] || NOCONFIGURE=true $(ROOT_DIR)/lib/libqalculate/autogen.sh
	CFLAGS="-I$(PREFIX)/include" LDFLAGS="-L$(PREFIX)/lib" \
	LIBXML_CFLAGS="-I$(PREFIX)/include/libxml2" LIBXML_LIBS="$(LDFLAGS)" \
	    emconfigure $(ROOT_DIR)/lib/libqalculate/configure \
	        --build "$$($(ROOT_DIR)/lib/libqalculate/config.guess)" --host none --prefix="$(PREFIX)" \
		    --without-libcurl --without-icu --disable-textport --disable-nls --with-gnuplot-call=byo \
		    --enable-compiled-definitions
$(build)/gnuplot/Makefile: $(ACTIVATE_EMSDK) $(call libreqs,GNUPLOT) | lib/gnuplot
	$(EMSDK_ENV)
	$(CD_BUILDDIR)
	emconfigure $(ROOT_DIR)/lib/gnuplot/configure \
		--host none --prefix="$(PREFIX)" \
		--without-readline --without-x --disable-wxwidgets --without-qt

submake_args = -C $(<D) CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)" LDFLAGS="$(LDFLAGS)"

$(LIBDIR)/libxml2.a: $(build)/libxml2/Makefile | lib/libxml2
	$(EMSDK_ENV)
	$(MAKE) $(submake_args) install PROGRAMS=''

$(LIBDIR)/libgmp.a: $(build)/gmp/Makefile | lib/gmp
	$(EMSDK_ENV)
	$(MAKE) $(submake_args) install

$(LIBDIR)/libmpfr.a: $(build)/mpfr/Makefile | lib/mpfr
	$(EMSDK_ENV)
	$(MAKE) $(submake_args) install

$(LIBDIR)/libqalculate.a: $(build)/libqalculate/Makefile | lib/libqalculate
	$(EMSDK_ENV)
	$(MAKE) $(submake_args) install

GNUPLOT_BINS := $(build)/install/bin/gnuplot.js $(build)/install/bin/gnuplot.wasm
$(GNUPLOT_BINS) &: $(build)/gnuplot/Makefile | lib/gnuplot
	$(EMSDK_ENV)
	$(MAKE) $(submake_args) gnuplot
	mkdir -p $(build)
	install -Dm 644 $(<D)/src/gnuplot $(@D)/gnuplot.js
	install -D $(<D)/src/gnuplot.wasm $(@D)/gnuplot.wasm

OBJS = $(patsubst src/%.cpp,src/%.o,$(wildcard src/*.cpp))

src/%.o: src/%.cpp $(LIBDIR)/libqalculate.a
	$(EMSDK_ENV)
	emcc --bind $(CXXFLAGS) -Oz -c $< -o $@

$(build)/qalc.js $(build)/qalc.wasm &: $(OBJS) $(call libfiles,$(QALCWASM_LIBS))
	$(EMSDK_ENV)
	mkdir -p $(@D)
	emcc \
	    --bind \
	    $(LDFLAGS) \
	    -s WARN_UNALIGNED=1 -s ERROR_ON_UNDEFINED_SYMBOLS=0 -s FILESYSTEM=0 -s ASSERTIONS=0 \
	    $(call prepend,-l,$(QALCWASM_LIBS)) \
	    $(OBJS) \
	    -o $(build)/qalc.js

PUBLIC_FILES = $(build)/qalc.js $(build)/qalc.wasm $(GNUPLOT_BINS) \
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
	$(foreach libdir,$(call prepend,$(build)/,$(ALL_LIBS)),[ -d $(libdir) ] && $(MAKE) -C $(libdir) clean
	)@true
