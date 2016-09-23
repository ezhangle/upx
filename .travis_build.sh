#! /bin/bash
## vim:set ts=4 sw=4 et:
set -e; set -o pipefail


if test "X$B" = "X"; then B=make/release; fi
if test "X$B" = "debug"; then B=make/debug; fi
BUILD_METHOD_AND_BUILD_TYPE="$B"

if test "X$C" = "Xclang"; then
  export CC="clang $A" CXX="clang++ $A"
elif test "X$C" = "Xgcc"; then
  export CC="gcc $A" CXX="g++ $A"
elif test "X$C" = "Xgcc-5"; then
  export CC="gcc-5 $A" CXX="g++-5 $A"
fi

export UPX_UCLDIR="$TRAVIS_BUILD_DIR/deps/ucl-1.03"


echo "BUILD_METHOD_AND_BUILD_TYPE='$BUILD_METHOD_AND_BUILD_TYPE'"
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

# build UCL
cd /
set -x
cd "$UPX_UCLDIR"
./configure --enable-static --disable-shared
make

zsh --version || true

# build UPX
cd /
set -x
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"
f="EXTRA_CPPFLAGS=-DUCL_NO_ASM"
make="make -f $TRAVIS_BUILD_DIR/src/Makefile $f"
if "X$ALLOW_FAIL" = "X1"; then set +e; fi
case $BUILD_METHOD_AND_BUILD_TYPE in
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
    echo "ERROR: invalid build '$BUILD_METHOD_AND_BUILD_TYPE'"
    exit 1
    ;;
esac

# very fist version of the upx-testsuite
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
    rm -f *.tmp
    $upx_391 -d $f -o v391.tmp
    $upx     -d $f -o v392.tmp
    sha256sum v391.tmp v392.tmp
    cmp -s v391.tmp v392.tmp
    rm -f *.tmp
done
fi
