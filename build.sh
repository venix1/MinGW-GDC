# Configuration options

# Which branch to build against
GDC_BRANCH="master"
GCC_DOWNLOAD="http://mirrors.concertpass.com/gcc/releases/gcc-4.9.2/gcc-4.9.2.tar.bz2"
GCC_VERSION="4.9.2"
BUILD_PATH="/crossdev/gdc-$GCC_VERSION"

BINUTILS_VERSION=
GDC_BRANCH=gdc-4.9
# specific commit. Empty is head
GDC_COMMIT=

export GDC_BRANCH GCC_VERSION BUILD_PATH GDC_BRANCH GDC_COMMIT


# Exit on error
set -e 

	
### Build Code
# Sanity test
DRIVE=$(pwd -W | cut -c 1)
mkdir -p /$DRIVE$BUILD_PATH/src
if [ ! -d $BUILD_PATH ]; then
	echo "Santity test failed. /$DRIVE/crossdev does not map to /crossdev"
	echo "Please ensure a mapping to crossdev exists in /etc/fstab"
	echo "/crossdev must exist on the same drive this script is executed from"
	exit 1
fi

wget=$(which wget 2>/dev/null)
if [ "$wget" == "" ]; then
	echo "wget not installed.  Please install with:"
	echo "mingw-get install msys-wget"
	exit 1
fi

unzip=$(which unzip 2>/dev/null)
if [ "$unzip" == "" ]; then
	echo "unzip not installed.  Please install with:"
	echo "mingw-get install msys-unzip"
	exit 1
fi

patch=$(which patch 2>/dev/null)
if [ "$patch" == "" ]; then
	echo "patch not installed.  Please install via"
	echo "mingw-get install msys-patch"
	exit 1
fi

m4=$(which m4 2>/dev/null)
if [ "$m4" == "" ]; then
    echo "m4 not installed. Please install via"
	echo "mingw-get install msys-m4"
fi

root=$(pwd)
pushd $BUILD_PATH/src

# Download and install x86-64 build tools
if [ ! -e "7za.exe" ]; then
	if [ ! -e "7za920.zip" ]; then
		wget http://downloads.sourceforge.net/project/sevenzip/7-Zip/9.20/7za920.zip
	fi
	unzip 7za920.zip 7za.exe
fi
	
if [ ! -d "/crossdev/mingw64" ]; then
	if [ ! -e "x86_64-4.8.2-release-win32-sjlj-rt_v3-rev0.7z" ]; then
		wget "http://downloads.sourceforge.net/project/mingw-w64/Toolchains%20targetting%20Win64/Personal%20Builds/mingw-builds/4.9.2/threads-win32/sjlj/x86_64-4.9.2-release-win32-sjlj-rt_v3-rev1.7z"
	fi
	7za x -o/crossdev x86_64-4.9.2-release-win32-sjlj-rt_v3-rev1.7z
fi

export PATH=/crossdev/mingw64/bin:$PATH
# Configure x86-64 build environment
#gcc -v


# Install some basic DLL dependencies
mkdir -p $BUILD_PATH/release/bin

if [ ! -e "libiconv-1.14-3-mingw32-dll.tar.lzma" ]; then
#http://ftp.gnu.org/pub/gnu/libiconv/libiconv-1.14.tar.gz
	wget http://sourceforge.net/projects/mingw/files/MinGW/Base/libiconv/libiconv-1.14-3/libiconv-1.14-3-mingw32-dll.tar.lzma/download
#	tar --lzma -xvf libiconv-1.14-3-mingw32-dll.tar.lzma -C $BUILD_PATH/release
fi

if [ ! -e "gettext-0.18.3.1-1-mingw32-dll.tar.lzma" ]; then
	wget http://sourceforge.net/projects/mingw/files/MinGW/Base/gettext/gettext-0.18.3.1-1/gettext-0.18.3.1-1-mingw32-dll.tar.lzma/download
#	tar --lzma -xvf gettext-0.18.3.1-1-mingw32-dll.tar.lzma -C $BUILD_PATH/release
fi

if [ ! -e "gcc-core-4.8.1-3-mingw32-dll.tar.lzma" ]; then
	wget http://hivelocity.dl.sourceforge.net/project/mingw/MinGW/Base/gcc/Version4/gcc-4.8.1-3/gcc-core-4.8.1-3-mingw32-dll.tar.lzma
#	tar --lzma -xvf gcc-core-4.8.1-3-mingw32-dll.tar.lzma -C $BUILD_PATH/release bin/libgcc_s_dw2-1.dll 
fi

# Extracts archive and converts to git repo. 
# If git repo exists, resets
# $1 - archive
# $2 - path, for now, must equal what the archive extracts to
function mkgit {
	return
	if [ ! -d "$2" ]; then
		# Determine archive type
		ext="${$1##*.}"
		switch $ext
		tar -xvjf $1
		cd $2
		
		# prune unnecessary folders.
		git init
		git config user.email "nobody@localhost"
		git config user.name "Nobody"
		git config core.autocrlf false
		git add -f *
		git commit -am "MinGW/GDC restore point"
		cd ..
	else
		cd $2
		git reset --hard
		git clean -f	
		cd ..	
	fi	
}

# From this point forward, always exit on error
set -e

# Compile binutils
#mkgit binutils-2.25.tar.gz binutils-2.25
if [ ! -e binutils-2.25/build/.built ]; then
	if [ ! -e "binutils-2.25.tar.gz" ]; then
		wget http://ftp.gnu.org/gnu/binutils/binutils-2.25.tar.gz
	fi
	
	#mkgit binutils-2.25.tar.gz binutils-2.25
	if [ ! -d "binutils-2.25" ]; then
		tar -xvzf binutils-2.25.tar.gz
		cd binutils-2.25
		# prune unnecessary folders.
		git init
		git config user.email "nobody@localhost"
		git config user.name "Nobody"
		git config core.autocrlf false
		git add *
		git commit -m "MinGW/GDC restore point"
		cd ..
	else
		cd binutils-2.25
		git reset --hard
		git clean -f	
		cd ..
	fi	
	pushd binutils-2.25
	#patch -p1 < $root/patches/mingw-tls-binutils-2.23.1.patch
	mkdir -p build
	cd build
	../configure --prefix=$BUILD_PATH/release --build=x86_64-w64-mingw32 \
	  --enable-targets=x86_64-w64-mingw32,i686-w64-mingw32 \
	  CFLAGS="-O2" LDFLAGS="-s"
	make && make install
	touch .built
	popd 
fi

# Compile MinGW64 runtime
if [ ! -e mingw-w64-v4.0-rc2/build/.built ]; then
	if [ ! -e "mingw-w64-v4.0-rc2.tar.bz2" ]; then
		wget http://downloads.sourceforge.net/project/mingw-w64/mingw-w64/mingw-w64-release/mingw-w64-v4.0-rc2.tar.bz2
	fi

	if [ ! -d "mingw-w64-v4.0-rc2" ]; then
		tar -xvjf mingw-w64-v4.0-rc2.tar.bz2
		cd mingw-w64-v4.0-rc2
		# prune unnecessary folders.
		git init
		git config user.email "nobody@localhost"
		git config user.name "Nobody"
		git config core.autocrlf false
		git add *
		git commit -am "MinGW/GDC restore point"
		cd ..
	else
		cd mingw-w64-v4.0-rc2
		git reset --hard
		git clean -f	
		cd ..
	fi		
	pushd mingw-w64-v4.0-rc2
	mkdir -p build/
	cd build
	# Handle mingw-w64-libraries
	../configure --prefix=$BUILD_PATH/release/x86_64-w64-mingw32 --host=x86_64-w64-mingw32 \
	  --enable-lib32 --enable-sdk=all
	pushd mingw-w64-headers
	make && make install
	popd
	make && make install
	
	touch .built
	popd 
fi

# Compile GMP
if [ ! -e gmp-4.3.2/build/.built ]; then
	if [ ! -e "gmp-4.3.2.tar.bz2" ]; then
		wget http://ftp.gnu.org/gnu/gmp/gmp-4.3.2.tar.bz2
	fi
	
	if [ ! -d "gmp-4.3.2" ]; then
		tar -xvjf gmp-4.3.2.tar.bz2
		cd gmp-4.3.2
		# prune unnecessary folders.
		git init
		git config user.email "nobody@localhost"
		git config user.name "Nobody"
		git config core.autocrlf false
		git add *
		git commit -am "MinGW/GDC restore point"
		cd ..
	else
		cd gmp-4.3.2
		git reset --hard
		git clean -f	
		cd ..
	fi			

	pushd gmp-4.3.2
	patch -p1 < $root/patches/gmp-4.3.2-w64.patch

	# Make 32
	mkdir -p build/32
	cd build/32
	../../configure --prefix=$BUILD_PATH/gmp-4.3.2/32 \
	  --build=x86_64-w64-mingw32 --enable-cxx --disable-static --enable-shared \
	  LD="ld.exe -m i386pe" CFLAGS="-O2 -m32" CXXFLAGS="-O2 -m32" \
	  LDFLAGS="-m32 -s" ABI=32
	make && make install
	cd ../..

	# Make 64
	mkdir -p build/64
	cd build/64
	../../configure --prefix=$BUILD_PATH/gmp-4.3.2/64 \
	  --build=x86_64-w64-mingw32 --enable-cxx --disable-static --enable-shared \
	  CFLAGS="-O2" CXXFLAGS="-O2" LDFLAGS="-s" ABI=64 \
	  NM=/crossdev/mingw64/bin/nm
	make && make install
	cd ..
	touch .built
	popd
fi
# Compile MPFR
if [ ! -e mpfr-3.1.1/build/.built ]; then
	if [ ! -e "mpfr-3.1.1.tar.bz2" ]; then
		wget http://ftp.gnu.org/gnu/mpfr/mpfr-3.1.1.tar.bz2
	fi
	
	if [ ! -d "mpfr-3.1.1" ]; then
		tar -xvjf mpfr-3.1.1.tar.bz2
		cd mpfr-3.1.1
		# prune unnecessary folders.
		git init
		git config user.email "nobody@localhost"
		git config user.name "Nobody"
		git config core.autocrlf false
		git add *
		git commit -am "MinGW/GDC restore point"
		cd ..
	else
		cd mpfr-3.1.1
		git reset --hard
		git clean -f	
		cd ..	
	fi
	
	pushd mpfr-3.1.1
	# Make 32
	mkdir -p build/32
	cd build/32
	#export PATH="$(PATH):$(GMP_STAGE)/32/bin"
	../../configure --prefix=$BUILD_PATH/mpfr-3.1.1/32 \
	  --build=x86_64-w64-mingw32 --disable-static --enable-shared \
	  CFLAGS="-O2 -m32 -I$BUILD_PATH/gmp-4.3.2/32/include" \
	  LDFLAGS="-m32 -s -L$BUILD_PATH/gmp-4.3.2/32/lib"
	make && make install
	cd ../..
	# Make 64
	mkdir -p build/64
	cd build/64
	#export PATH="$(PATH):$(GMP_STAGE)/64/bin"
	../../configure --prefix=$BUILD_PATH/mpfr-3.1.1/64 \
	  --build=x86_64-w64-mingw32 --disable-static --enable-shared \
	  CFLAGS="-O2 -I$BUILD_PATH/gmp-4.3.2/64/include" \
	  LDFLAGS="-s -L$BUILD_PATH/gmp-4.3.2/64/lib"
	make && make install
	cd ..
	touch .built
	popd
fi

# Compile MPC
if [ ! -e mpc-1.0.1/build/.built ]; then
	if [ ! -e "mpc-1.0.1.tar.gz" ]; then
		wget http://ftp.gnu.org/gnu/mpc/mpc-1.0.1.tar.gz
	fi
	
	if [ ! -d "mpc-1.0.1" ]; then
		tar -xvzf mpc-1.0.1.tar.gz
		cd mpc-1.0.1
		# prune unnecessary folders.
		git init
		git config user.email "nobody@localhost"
		git config user.name "Nobody"
		git config core.autocrlf false
		git add *
		git commit -am "MinGW/GDC restore point"
		cd ..
	else
		cd mpc-1.0.1
		git reset --hard
		git clean -f	
		cd ..	
	fi	

	
	pushd mpc-1.0.1
	# Make 32
	mkdir -p build/32
	cd build/32
	../../configure --prefix=$BUILD_PATH/mpc-1.0.1/32 \
	  --build=x86_64-w64-mingw32 --disable-static --enable-shared \
	  --with-gmp=$BUILD_PATH/gmp-4.3.2/32 \
	  --with-mpfr=$BUILD_PATH/mpfr-3.1.1/32 \
	  CFLAGS="-O2 -m32" LDFLAGS="-m32 -s"
	make && make install
	cd ../..
	# Make 64
	mkdir -p build/64
	cd build/64
	../../configure --prefix=$BUILD_PATH/mpc-1.0.1/64 \
	  --build=x86_64-w64-mingw32 --disable-static --enable-shared \
	  --with-gmp=$BUILD_PATH/gmp-4.3.2/64 \
	  --with-mpfr=$BUILD_PATH/mpfr-3.1.1/64 \
	  CFLAGS="-O2" LDFLAGS="-s"
	  make && make install
	cd ..
	
	touch .built
	popd
fi

# Compile ISL
if [ ! -e isl-0.11.1/build/.built ]; then
	if [ ! -e "isl-0.11.1.tar.bz2" ]; then
		wget ftp://gcc.gnu.org/pub/gcc/infrastructure/isl-0.11.1.tar.bz2
	fi
	
	#mkgit isl-0.11.1.tar.bz2 isl-0.11.1
	if [ ! -d "isl-0.11.1" ]; then
		tar -xvjf isl-0.11.1.tar.bz2
		cd isl-0.11.1
		
		# prune unnecessary folders.
		git init
		git config user.email "nobody@localhost"
		git config user.name "Nobody"
		git config core.autocrlf false
		git add *
		git commit -am "MinGW/GDC restore point"
		cd ..
	else
		cd isl-0.11.1
		git reset --hard
		git clean -f	
		cd ..	
	fi	

	pushd isl-0.11.1
	mkdir -p build/32
	cd build/32
	../../configure --prefix=$BUILD_PATH/isl-0.11.1/32 \
	  --build=x86_64-w64-mingw32 --enable-shared \
	  --with-gmp-prefix=$BUILD_PATH/gmp-4.3.2/32 \
	  CFLAGS="-O2 -m32" LDFLAGS="-m32 -s"
	make && make install
	cd ../..
	# Make 64
	mkdir -p build/64
	cd build/64
	../../configure --prefix=$BUILD_PATH/isl-0.11.1/64 \
	  --build=x86_64-w64-mingw32 --enable-shared \
	  --with-gmp-prefix=$BUILD_PATH/gmp-4.3.2/64 \
	  CFLAGS="-O2" LDFLAGS="-s"
	  make && make install
	cd ..

	touch .built
	popd
fi

# Compile CLOOG
if [ ! -e cloog-0.18.0/build/.built ]; then
	if [ ! -e "cloog-0.18.0.tar.gz" ]; then
	wget ftp://gcc.gnu.org/pub/gcc/infrastructure/cloog-0.18.0.tar.gz
	fi

	#mkgit cloog-0.18.0.tar.gz cloog-0.18.0
	if [ ! -d "cloog-0.18.0" ]; then
		tar -xvzf cloog-0.18.0.tar.gz
		cd cloog-0.18.0
		
		# prune unnecessary folders.
		git init
		git config user.email "nobody@localhost"
		git config user.name "Nobody"
		git config core.autocrlf false
		git add -f *
		git commit -am "MinGW/GDC restore point"
		cd ..
	else
		cd cloog-0.18.0
		git reset --hard
		git clean -f	
		cd ..	
	fi	
	
	pushd cloog-0.18.0
	# Build 32
	mkdir -p build/32
	cd build/32
	 #export PATH="$(PATH):$(GMP_STAGE)/32/bin:$(PPL_STAGE)/32/bin"
	../../configure --prefix=$BUILD_PATH/cloog-0.18.0/32 \
	  --build=x86_64-w64-mingw32 --disable-static --enable-shared \
	  --with-gmp-prefix=$BUILD_PATH/gmp-4.3.2/32 \
      --with-isl-prefix=$BUILD_PATH/isl-0.11.1/32 \
	  CFLAGS="-O2 -m32" CXXFLAGS="-O2 -m32" LDFLAGS="-s -m32"
	  make && make install
	cd ../..
	# Build 64
	mkdir -p build/64
	cd build/64
	 #export PATH="$(PATH):$(GMP_STAGE)/32/bin:$(PPL_STAGE)/32/bin"
	../../configure --prefix=$BUILD_PATH/cloog-0.18.0/64 \
	  --build=x86_64-w64-mingw32 --disable-static --enable-shared \
	  --with-gmp-prefix=$BUILD_PATH/gmp-4.3.2/64 \
      --with-isl-prefix=$BUILD_PATH/isl-0.11.1/64 \
	  CFLAGS="-O2" CXXFLAGS="-O2" LDFLAGS="-s"
	make && make install
	cd ..
	touch .built
	popd
fi

export GCC_PREFIX="$BUILD_PATH/release"

# Copy runtime files to release
mkdir -p $GCC_PREFIX/x86_64-w64-mingw32
mkdir -p $GCC_PREFIX/x86_64-w64-mingw32/bin32
mkdir -p $GCC_PREFIX/x86_64-w64-mingw32/lib32

GMP_STAGE=$BUILD_PATH/gmp-4.3.2/
MPFR_STAGE=$BUILD_PATH/mpfr-3.1.1/
MPC_STAGE=$BUILD_PATH/mpc-1.0.1/
ISL_STAGE=$BUILD_PATH/isl-0.11.1/
CLOOG_STAGE=$BUILD_PATH/cloog-0.18.0/

cp -Rp $GMP_STAGE/64/*		$GCC_PREFIX/x86_64-w64-mingw32/
cp -Rp $GMP_STAGE/32/bin/*	$GCC_PREFIX/x86_64-w64-mingw32/bin32
cp -Rp $GMP_STAGE/32/lib/*	$GCC_PREFIX/x86_64-w64-mingw32/lib32

cp -Rp $MPFR_STAGE/64/*     $GCC_PREFIX/x86_64-w64-mingw32
cp -Rp $MPFR_STAGE/32/bin/* $GCC_PREFIX/x86_64-w64-mingw32/bin32
cp -Rp $MPFR_STAGE/32/lib/* $GCC_PREFIX/x86_64-w64-mingw32/lib32

cp -Rp $MPC_STAGE/64/*     $GCC_PREFIX/x86_64-w64-mingw32
cp -Rp $MPC_STAGE/32/bin/* $GCC_PREFIX/x86_64-w64-mingw32/bin32
cp -Rp $MPC_STAGE/32/lib/* $GCC_PREFIX/x86_64-w64-mingw32/lib32

cp -Rp $ISL_STAGE/64/*     $GCC_PREFIX/x86_64-w64-mingw32
#cp -Rp $ISL_STAGE/32/bin/* $GCC_PREFIX/x86_64-w64-mingw32/bin32
cp -Rp $ISL_STAGE/32/lib/* $GCC_PREFIX/x86_64-w64-mingw32/lib32

cp -Rp $CLOOG_STAGE/64/*     $GCC_PREFIX/x86_64-w64-mingw32
cp -Rp $CLOOG_STAGE/32/bin/* $GCC_PREFIX/x86_64-w64-mingw32/bin32
cp -Rp $CLOOG_STAGE/32/lib/* $GCC_PREFIX/x86_64-w64-mingw32/lib32

cp -Rp $GCC_PREFIX/x86_64-w64-mingw32/bin/*.dll $GCC_PREFIX/bin


# Setup GDC and compile
function build_gdc {
	fname=$(basename $GCC_DOWNLOAD)
	dname=$(basename $GCC_DOWNLOAD .tar.bz2)
	if [ ! -e "$fname" ]; then
		wget $GCC_DOWNLOAD
	fi

	# Extract and configure a git repo to allow fast restoration for future builds.
	# mkgit gcc-4.8.1.tar.bz2 gcc-4.8.1
	if [ ! -d "$dname" ]; then
		tar -xvjf $fname
		cd $dname
		# prune unnecessary folders.
		git init
		git config user.email "nobody@localhost"
		git config user.name "Nobody"
		git config core.autocrlf false
		git add -f *
		git commit -am "MinGW/GDC restore point"
		git tag mingw_build
		cd ..
	else
		cd $dname
		git reset --hard mingw_build
		git clean -f -d	
		cd ..
	fi
	# Clone and configure GDC
	if [ ! -d "GDC" ]; then
		git clone https://github.com/D-Programming-GDC/GDC.git -b $GDC_BRANCH
	else
		cd GDC
		git fetch 
		git reset --hard origin/$GDC_BRANCH
		git clean -f -d
		cd ..
	fi
	
	pushd GDC
	
	if [ "$GDC_VERSION" != "" ]; then
		git checkout $GDC_VERSION
	fi
	
	#patch -p1 < $root/patches/mingw-gdc.patch
	#patch -p1 < $root/patches/mingw-gdc-remove-main-from-dmain2.patch
	# Should use git am
	for patch in $(find $root/patches/gdc -type f -name '*.patch'); do
		echo "Patching $patch"
		git am -3 --ignore-whitespace $patch || exit
	done
	./setup-gcc.sh ../$dname
	popd

	pushd $dname
	patch -p1 < $root/patches/mingw-tls-gcc-4.8.patch
	
	# Should use git am
	for patch in $(find $root/patches/gcc -type f ); do
		echo "Patching $patch"
		git am $patch || exit
	done

	# Build GCC
	mkdir -p build
	cd build
	
	# Must build GCC using patched mingwrt
	export LPATH="$GCC_PREFIX/lib;$GCC_PREFIX/x86_64-w64-mingw32/lib"
	export CPATH="$GCC_PREFIX/include;$GCC_PREFIX/x86_64-w64-mingw32/include"
	#export BOOT_CFLAGS="-static-libgcc -static"
	../configure --prefix=$GCC_PREFIX --with-local-prefix=$GCC_PREFIX \
	  --build=x86_64-w64-mingw32 --enable-targets=all \
	  --enable-languages=c,c++,d,lto --enable-sjlj-exceptions \
	  --enable-lto --enable-version-specific-runtime-libs \
	  --enable-threads=win32 \
	  --disable-win32-registry --with-gnu-ld \
	  --with-pkgversion="MinGW-GDC64" \
	  --with-bugurl="http://gdcproject.org/bugzilla/" \
	  --disable-shared --disable-bootstrap
	make && make install
	
	# Compile 32-bit libgphobos manually due to bug
	cd x86_64-w64-mingw32/32/libphobos/
	make && make install

	popd
}

export PATH="$GCC_PREFIX/bin:$PATH"
build_gdc
exit

# get DMD script
if [ ! -d "GDMD" ]; then
	git clone https://github.com/D-Programming-GDC/GDMD.git
else
	cd GDMD
	git pull
	cd ..
fi
pushd GDMD

#Ok to fail. results in testsuite not running
PATH=/d/strawberry/perl/bin:$PATH TMPDIR=. cmd /c "pp dmd-script -o gdmd.exe"
cp gdmd.exe $BUILD_PATH/release/bin/
cp dmd-script $BUILD_PATH/release/bin/gdmd
popd

# Test build
# Run unitests via check-d
# Verify gdmd exists.
# test commands need to avoid exit on error
echo -n "Checking for gdmd.exe..." 
gdmd=$(which gdmd.exe 2>/dev/null)
if [ ! "$gdmd" ]; then
	echo "Unable to run DMD testsuite. gdmd.exe failed to compile"
	exit 1
fi

# Run testsuite via dmd
echo "dmd cloning"
if [ ! -d "dmd" ]; then
	git clone https://github.com/D-Programming-Language/dmd.git -b 2.064
else
	cd dmd
	git reset --hard
	git clean -f
	git pull
	# Reset RPO
	cd ..
fi
pushd dmd/test
patch -p2 < $root/patches/mingw-testsuite.patch
make
pushd