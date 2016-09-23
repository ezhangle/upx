#! /bin/bash
## vim:set ts=4 sw=4 et:
set -e; set -o pipefail


if test "X$B" = "X"; then B=make/release; fi
if test "X$B" = "Xdebug"; then B=make/debug; fi
BUILD_METHOD="$B"

if test "X$C" = "Xclang"; then
  export CC="clang $A" CXX="clang++ $A"
elif test "X$C" = "Xgcc"; then
  export CC="gcc $A" CXX="g++ $A"
elif test "X$C" = "Xgcc-5"; then
  export CC="gcc-5 $A" CXX="g++-5 $A"
fi

export UPX_UCLDIR="$TRAVIS_BUILD_DIR/deps/ucl-1.03"

echo "BUILD_METHOD='$BUILD_METHOD'"
echo "CC='$CC'"
echo "CXX='$CXX'"
echo "CPPFLAGS='$CPPFLAGS'"
echo "CFLAGS='$CFLAGS'"
echo "CXXFLAGS='$CXXFLAGS'"
echo "LDFLAGS='$LDFLAGS'"
echo "LIBS='$LIBS'"
echo "BUILD_DIR='$BUILD_DIR'"
echo "UPX_UCLDIR='$UPX_UCLDIR'"
#env | LC_ALL=C sort

echo "$CC --version"; $CC --version
echo "$CXX --version"; $CXX --version

set -x

# build UCL
cd /
cd "$UPX_UCLDIR"
./configure --enable-static --disable-shared
make

# build UPX
cd /
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
f="EXTRA_CPPFLAGS=-DUCL_NO_ASM"
make="make -f $TRAVIS_BUILD_DIR/src/Makefile $f"
if test "X$ALLOW_FAIL" = "X1"; then set +e; fi
case $BUILD_METHOD in
make/debug)
    $make USE_DEBUG=1
    ;;
make/release)
    $make
    ;;
make/scan-build)
    if test "$CC" = "clang"; then
        scan-build $make
    else
        $make USE_SANITIZE=1
    fi
    ;;
*)
    echo "ERROR: invalid build '$BUILD_METHOD'"
    exit 1
    ;;
esac

# very first version of the upx-testsuite
if test -x $PWD/upx.out; then
file upx.out || true
upx="$PWD/upx.out"
cp "$TRAVIS_BUILD_DIR/deps/upx-testsuite/files/packed/amd64-linux.elf/upx-3.91" upx391.out
upx_391="$PWD/upx391.out"
$upx --help
cd "$TRAVIS_BUILD_DIR/deps/upx-testsuite/files"
$upx -l packed/*/upx-3.91*
$upx --file-info packed/*/upx-3.91*
for f in packed/*/upx-3.91*; do
    echo "===== $f"
    $upx_391 -d $f -o v391.tmp
    $upx     -d $f -o v392.tmp
    sha256sum v391.tmp v392.tmp
    cmp -s v391.tmp v392.tmp
    $upx_391 --fake-version-year=2016 --fake-stub-version="3.91" v391.tmp -o v391_packed.tmp
    $upx                                                         v392.tmp -o v392_packed.tmp
    sha256sum v391_packed.tmp v392_packed.tmp
    rm *.tmp
done
fi

exit 0
