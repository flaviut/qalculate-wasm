.ONESHELL:
SHELL := /bin/bash
.SHELLFLAGS = -ec

ROOT_DIR := $(PWD)
export PREFIX=$(ROOT_DIR)/lib/install/
export CFLAGS=-I$(PREFIX)/include -O3 -flto --profiling
export CXXFLAGS=$(CFLAGS) -fno-rtti -fno-exceptions
export LDFLAGS=-L$(PREFIX)/lib -flto


.PHONY: serve default
default: serve

lib/emsdk.tar.gz:
	aria2c --check-integrity=true --auto-file-renaming=false \
	    https://github.com/emscripten-core/emsdk/archive/2.0.11.tar.gz \
	    --out=lib/emsdk.tar.gz \
	    --checksum=sha-256=f366c569d10b5eedf56edab86f4e834ca3a5ca0bf4f9ab1818d8575afd10277b
lib/gmp.tar.xz:
	aria2c --check-integrity=true --auto-file-renaming=false \
	    https://ftp.gnu.org/gnu/gmp/gmp-6.2.1.tar.xz \
	    --out=lib/gmp.tar.xz \
	    --checksum=sha-256=fd4829912cddd12f84181c3451cc752be224643e87fac497b69edddadc49b4f2
lib/mpfr.tar.xz:
	aria2c --check-integrity=true --auto-file-renaming=false \
	    https://ftp.gnu.org/gnu/mpfr/mpfr-4.1.0.tar.xz \
	    --out=lib/mpfr.tar.xz \
	    --checksum=sha-256=0c98a3f1732ff6ca4ea690552079da9c597872d30e96ec28414ee23c95558a7f
lib/libxml2.tar.gz:
	aria2c --check-integrity=true --auto-file-renaming=false \
	    http://xmlsoft.org/sources/libxml2-2.9.10.tar.gz \
	    --out=lib/libxml2.tar.gz \
	    --checksum=sha-256=aafee193ffb8fe0c82d4afef6ef91972cbaf5feea100edc2f262750611b4be1f

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
	git reset --hard v3.15.0
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

lib/emsdk/upstream/.emsdk_version: lib/emsdk
	pushd lib/emsdk
	./emsdk install 2.0.9
	./emsdk activate 2.0.9

lib/build/libxml2/Makefile: lib/emsdk/upstream/.emsdk_version lib/libxml2
	. lib/emsdk/emsdk_env.sh
	mkdir -p lib/build/libxml2
	cd lib/build/libxml2
	emconfigure ../../libxml2/configure --host none --prefix="${PREFIX}" \
	    --with-minimum --with-sax1 --with-tree --with-output
lib/build/gmp/Makefile: lib/emsdk/upstream/.emsdk_version lib/gmp
	. lib/emsdk/emsdk_env.sh
	mkdir -p lib/build/gmp
	cd lib/build/gmp
	emconfigure ../../gmp/configure --host none --prefix="${PREFIX}" \
		--disable-assembly --disable-cxx --disable-fft \
		--enable-alloca=notreentrant
lib/build/mpfr/Makefile: lib/emsdk/upstream/.emsdk_version lib/mpfr lib/install/lib/libgmp.a
	. lib/emsdk/emsdk_env.sh
	mkdir -p lib/build/mpfr
	cd lib/build/mpfr
	emconfigure ../../mpfr/configure --host none --prefix="${PREFIX}" \
		--disable-thread-safe --enable-decimal-float=no
lib/build/libqalculate/Makefile: lib/emsdk/upstream/.emsdk_version lib/libqalculate lib/install/lib/libgmp.a lib/install/lib/libmpfr.a lib/install/lib/libxml2.a
	. lib/emsdk/emsdk_env.sh
	mkdir -p lib/build/libqalculate
	cd lib/build/libqalculate
	NOCONFIGURE=true ../../libqalculate/autogen.sh
	LIBXML_CFLAGS="-I${PREFIX}/include/libxml2" LIBXML_LIBS="${LDFLAGS}" \
	    emconfigure ../../libqalculate/configure \
	        --host none --prefix="${PREFIX}" \
		    --without-libcurl --without-icu --disable-textport --disable-nls --without-gnuplot-call \
		    --enable-compiled-definitions

lib/install/lib/libxml2.a: lib/emsdk/upstream/.emsdk_version lib/build/libxml2/Makefile
	. lib/emsdk/emsdk_env.sh
	$(MAKE) -C lib/build/libxml2 PROGRAMS= install

lib/install/lib/libgmp.a: lib/emsdk/upstream/.emsdk_version lib/build/gmp/Makefile
	. lib/emsdk/emsdk_env.sh
	$(MAKE) -C lib/build/gmp install

lib/install/lib/libmpfr.a: lib/emsdk/upstream/.emsdk_version lib/build/mpfr/Makefile
	. lib/emsdk/emsdk_env.sh
	$(MAKE) -C lib/build/mpfr install

lib/install/lib/libqalculate.a: lib/emsdk/upstream/.emsdk_version lib/build/libqalculate/Makefile
	. lib/emsdk/emsdk_env.sh
	$(MAKE) -C lib/build/libqalculate install

build/qalc.js build/qalc.wasm: lib/emsdk/upstream/.emsdk_version lib/install/lib/libqalculate.a $(wildcard src/*.cpp)
	. lib/emsdk/emsdk_env.sh
	mkdir -p build
	export EMMAKEN_CFLAGS="$(CFLAGS) $(CXXFLAGS) $(LDFLAGS)"
	emcc \
	    --source-map-base http://localhost:8000/build/ \
	    -Oz -gseparate-dwarf \
	    -s WARN_UNALIGNED=1 -s ERROR_ON_UNDEFINED_SYMBOLS=0 -s FILESYSTEM=0 \
	    -s EXPORTED_FUNCTIONS='["_calculate", "_free", "_newCalculator"]' \
	    -s EXTRA_EXPORTED_RUNTIME_METHODS='["cwrap"]' \
	    -llibqalculate -lgmp -lmpfr -lxml2 \
	    $(ROOT_DIR)/src/*.cpp \
	    -o build/qalc.js


serve: build/qalc.js
	python3 -m http.server 8000

.PHONY: deploy
deploy: build/qalc.js index.html
	mkdir -p public/build
	cp build/* public/build/
	cp index.html public/
