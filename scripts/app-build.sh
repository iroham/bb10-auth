#!/bin/bash
# Build the Auth window (build/qnx/auth) against the BB10 SDK (gcc 4.8 libstdc++, Qt 4.8, Cascades). No core lib,
# no network — TOTP is computed in-process (src/totp.cpp).
set -e
. /w/toolchain/qnx-env.sh
cd /t; O=build/qnx/obj; mkdir -p $O
GXX=$QT/usr/include/c++/4.8.3
INC="-nostdinc++ -isystem $GXX -isystem $GXX/arm-unknown-nto-qnx8.0.0eabi -isystem $GXX/backward $QNX_SYSINC -isystem $QT/usr/include/qt4 -isystem $QT/usr/include/qt4/QtCore -isystem $QT/usr/include/qt4/QtGui -isystem $QT/usr/include/qt4/QtDeclarative -isystem $QT/usr/include/qt4/QtNetwork -Isrc -I$O"
FL="-std=gnu++98 -O2 -Wall -Wno-pragma-pack -fvisibility=hidden -DQT_NO_DEBUG -DQT_DECLARATIVE_LIB -DQT_CORE_LIB"
QTL="-L$QT/armle-v7/usr/lib/qt4/lib -L$QT/armle-v7/lib/gcc/4.8.3 -rpath-link=$QT/armle-v7/usr/lib/qt4/lib --disable-new-dtags -rpath app/native/lib:/usr/lib/qt4/lib"
OBJS=""
for h in src/*.h; do
  if grep -q Q_OBJECT $h; then n=$(basename ${h%.h}); /b/host/moc -DQ_OS_BLACKBERRY $h -o $O/moc_$n.cpp; $QNX_CXX $FL $INC -c $O/moc_$n.cpp -o $O/moc_$n.o & OBJS="$OBJS $O/moc_$n.o"; fi
done
for c in src/*.cpp; do n=$(basename ${c%.cpp}); $QNX_CXX $FL $INC -c $c -o $O/$n.o & OBJS="$OBJS $O/$n.o"; done
wait
for o in $OBJS; do [ -f $o ] || { echo "compile failed: $o"; exit 1; }; done
$QNX_LD $QNX_LDFLAGS_EXE $QTL $OBJS \
  -lbb -lbbcascades -lbbdata -lbbsystem -lbbplatform -lQtDeclarative -lQtGui -lQtNetwork -lQtCore -lstdc++ -lm $QNX_LIBS_EXE -o build/qnx/auth
$CLANG/llvm-strip --strip-unneeded build/qnx/auth
ls -la build/qnx/auth; $CLANG/llvm-readelf -d build/qnx/auth | grep -E "NEEDED|RPATH|RUNPATH"
