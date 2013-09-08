# Sanity test
DRIVE=$(pwd -W | cut -c 1)
mkdir -p /$DRIVE/crossdev/gdc-4.8/src
if [ ! -d /crossdev/gdc-4.8 ]; then
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

root=$(pwd)
pushd /crossdev/gdc-4.8/src

# Extracts archive and converts to git repo. For patch maintenance and rebuilds
function extract_to_git {
	return
	
	# Identify archive type
	# Configure tar arguments
	# Extract and gitify archive
	if [ ! -d "$path" ]; then
		tar $args $1
		if [ "$2" ]; then
			mv "$path $2"
			path=$2
		fi
		cd $path
		git init
		git config user.email "nobody@localhost"
		git config user.name "Nobody"
		git config core.autocrlf false
		git add *
		git commit -m "MinGW/GDC restore point"
		cd ..
	else
		if [ "$2" ]; then path=$2; fi
		cd $path
		git reset --hard
		git clean -f	
		cd ..
	fi			
}

# From this point forward, always exit on error
set -e

# Compile binutils
if [ ! -e binutils-2.23.2/build/.built ]; then
	if [ ! -e "binutils-2.23.2.tar.gz" ]; then
		wget http://ftp.gnu.org/gnu/binutils/binutils-2.23.2.tar.gz
	fi
	
	#extract_to_git binutils-2.23.2.tar.gz
	if [ ! -d "binutils-2.23.2" ]; then
		tar -xvzf binutils-2.23.2.tar.gz
		cd binutils-2.23.2
		# prune unnecessary folders.
		git init
		git config user.email "nobody@localhost"
		git config user.name "Nobody"
		git config core.autocrlf false
		git add *
		git commit -m "MinGW/GDC restore point"
		cd ..
	else
		cd binutils-2.23.2
		git reset --hard
		git clean -f	
		cd ..
	fi	
	pushd binutils-2.23.2
	patch -p1 < $root/patches/mingw-tls-binutils-2.23.1.patch
	mkdir -p build
	cd build
	../configure --prefix=/crossdev/gdc-4.8/release --build=i686-mingw32
	make && make install
	touch .built
	popd 
fi

# Compile Win32 api
if [ ! -e w32api/build/.built ]; then
	if [ ! -e "w32api-3.17-2-mingw32-src.tar.lzma" ]; then
		wget http://sourceforge.net/projects/mingw/files/MinGW/Base/w32api/w32api-3.17/w32api-3.17-2-mingw32-src.tar.lzma/download
	fi

	if [ ! -d "w32api" ]; then
		tar --lzma -xvf w32api-3.17-2-mingw32-src.tar.lzma 
		mv w32api-3.17-2-mingw32 w32api
		cd w32api
		# prune unnecessary folders.
		git init
		git config user.email "nobody@localhost"
		git config user.name "Nobody"
		git config core.autocrlf false
		git add *
		git commit -am "MinGW/GDC restore point"
		cd ..
	else
		cd w32api
		git reset --hard
		git clean -f	
		cd ..
	fi		
	pushd w32api
	mkdir -p build
	cd build
	../configure --prefix=/crossdev/gdc-4.8/release --build=i686-mingw32
	make && make install
	touch .built
	popd 
fi

# Compile MinGW runtime
if [ ! -e mingwrt-3.20-mingw32/build/.built ]; then
	if [ ! -e "mingwrt-3.20-mingw32-src.tar.gz" ]; then
		wget http://sourceforge.net/projects/mingw/files/MinGW/Base/mingw-rt/mingwrt-3.20/mingwrt-3.20-mingw32-src.tar.gz/download
	fi

	tar -xvzf mingwrt-3.20-mingw32-src.tar.gz
	pushd mingwrt-3.20-mingw32
	patch -p1 < $root/patches/mingwrt_gdc.patch
	mkdir -p build
	cd build
	../configure --prefix=/crossdev/gdc-4.8/release --build=i686-mingw32
	make && make install
	touch .built
	popd
fi

# Compile GMP
if [ ! -e gmp-4.3.2/build/.built ]; then
	if [ ! -e "gmp-4.3.2.tar.bz2" ]; then
		wget http://ftp.gnu.org/gnu/gmp/gmp-4.3.2.tar.bz2
	fi

	tar -xvjf gmp-4.3.2.tar.bz2
	pushd gmp-4.3.2
	mkdir -p build
	cd build
	../configure --prefix=/crossdev/gdc-4.8/gmp-4.3.2 --build=i686-mingw32 --disable-shared
	make && make install
	touch .built
	popd
fi

# Compile MPFR
if [ ! -e mpfr-3.1.1/build/.built ]; then

	if [ ! -e "mpfr-3.1.1.tar.bz2" ]; then
		wget http://ftp.gnu.org/gnu/mpfr/mpfr-3.1.1.tar.bz2
	fi
	
	tar -xvjf mpfr-3.1.1.tar.bz2
	pushd mpfr-3.1.1
	mkdir -p build
	cd build
	../configure --prefix=/crossdev/gdc-4.8/mpfr-3.1.1 --build=i686-mingw32 --with-gmp=/crossdev/gdc-4.8/gmp-4.3.2 --disable-shared
	make && make install
	touch .built
	popd
fi

# Compile MPC
if [ ! -e mpc-1.0.1/build/.built ]; then
	if [ ! -e "mpc-1.0.1.tar.gz" ]; then
		wget http://ftp.gnu.org/gnu/mpc/mpc-1.0.1.tar.gz
	fi

	tar -xvzf mpc-1.0.1.tar.gz
	pushd mpc-1.0.1
	mkdir -p build
	cd build
	../configure --prefix=/crossdev/gdc-4.8/mpc-1.0.1 --build=i686-mingw32 --with-gmp=/crossdev/gdc-4.8/gmp-4.3.2 --with-mpfr=/crossdev/gdc-4.8/mpfr-3.1.1 --disable-shared
	make && make install
	touch .built
	popd
fi

# Compile ISL
if [ ! -e isl-0.11.1/build/.built ]; then
	if [ ! -e "isl-0.11.1.tar.bz2" ]; then
		wget ftp://gcc.gnu.org/pub/gcc/infrastructure/isl-0.11.1.tar.bz2
	fi

	tar -xvjf isl-0.11.1.tar.bz2
	pushd isl-0.11.1
	mkdir -p build
	cd build
	../configure --prefix=/crossdev/gdc-4.8/isl-0.11.1 --build=i686-mingw32 --with-gmp-prefix=/crossdev/gdc-4.8/gmp-4.3.2 --disable-shared
	make && make install
	touch .built
	popd
fi

# Compile CLOOG
if [ ! -e cloog-0.18.0/build/.built ]; then
	if [ ! -e "cloog-0.18.0.tar.gz" ]; then
	wget ftp://gcc.gnu.org/pub/gcc/infrastructure/cloog-0.18.0.tar.gz
	fi

	tar -xvzf cloog-0.18.0.tar.gz
	pushd cloog-0.18.0
	mkdir -p build
	cd build
	../configure --prefix=/crossdev/gdc-4.8/cloog-0.18.0 --build=i686-mingw32 --with-bits=gmp --with-gmp-prefix=/crossdev/gdc-4.8/gmp-4.3.2 --with-isl-prefix=/crossdev/gdc-4.8/isl-0.11.1 --disable-shared
	make && make install
	touch .built
	popd
fi

# Setup GDC and compile
function build_gdc {
	if [ ! -e "gcc-4.8.0.tar.bz2" ]; then
		wget http://ftp.gnu.org/gnu/gcc/gcc-4.8.0/gcc-4.8.0.tar.bz2	
	fi

	# Extract and configure a git repo to allow fast restoration for future builds.
	if [ ! -d "gcc-4.8.0" ]; then
		tar -xvjf gcc-4.8.0.tar.bz2
		cd gcc-4.8.0
		# prune unnecessary folders.
		git init
		git config user.email "nobody@localhost"
		git config user.name "Nobody"
		git config core.autocrlf false
		git add *
		git commit -am "MinGW/GDC restore point"
		cd ..
	else
		cd gcc-4.8.0
		git reset --hard
		git clean -f -d	
		cd ..
	fi
	# Clone and configure GDC
	if [ ! -d "GDC" ]; then
		git clone https://github.com/D-Programming-GDC/GDC.git -b gdc-4.8
	else
		cd GDC
		branch=$(git branch | cut -c3-)
		git fetch 
		git reset --hard origin/$branch
		git clean -f -d
		cd ..
	fi
	
	pushd GDC
	#patch -p1 < $root/patches/mingw-gdc.patch
	#patch -p1 < $root/patches/mingw-gdc-remove-main-from-dmain2.patch
	for patch in $(find $root/patches/gdc -type f ); do
		echo "Patching $patch"
		git am $patch || exit
	done
	./setup-gcc.sh ../gcc-4.8.0
	popd

	pushd gcc-4.8.0
	patch -p1 < $root/patches/mingw-tls-gcc-4.8.patch

	# Build GCC
	mkdir -p build
	cd build
	
	# Must build GCC using patched mingwrt
	export LPATH="$GCC_PREFIX/lib;$GCC_PREFIX/i686-pc-mingw32/lib"
	export CPATH="$GCC_PREFIX/include"

	../configure --prefix=$GCC_PREFIX --build=i686-mingw32 --with-gmp=/crossdev/gdc-4.8/gmp-4.3.2 --with-mpfr=/crossdev/gdc-4.8/mpfr-3.1.1 --with-mpc=/crossdev/gdc-4.8/mpc-1.0.1 --with-cloog=/crossdev/gdc-4.8/cloog-0.18.0 --with-isl=/crossdev/gdc-4.8/isl-0.11.1 --disable-bootstrap --enable-languages=c,c++,d,lto --enable-sjlj-exceptions 
	make && make install
	popd
}
export GCC_PREFIX="/crossdev/gdc-4.8/release"
export PATH="$GCC_PREFIX/bin:$PATH"
build_gdc

# get DMD scrtipt
if [ ! -d "GDMD" ]; then
	git clone https://github.com/D-Programming-GDC/GDMD.git
else
	cd GDMD
	git pull
	cd ..
fi
pushd GDMD
#Ok to fail. reults in testsuite not running
PATH=/c/strawberry/perl/bin:$PATH cmd /c "pp dmd-script -o gdmd.exe"
cp gdmd.exe /crossdev/gdc-4.8/release/bin/
cp dmd-script /crossdev/gdc-4.8/release/bin/gdmd
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
	git clone https://github.com/D-Programming-Language/dmd.git -b 2.062
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


