#!/bin/bash -ex

# Exit on error, rather than continuing with the rest of the script.
set -e

cd /yuzu

ccache -s

mkdir build || true && cd build
cmake .. -DDISPLAY_VERSION=$1 -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=/usr/lib/ccache/gcc -DCMAKE_CXX_COMPILER=/usr/lib/ccache/g++ -DYUZU_ENABLE_COMPATIBILITY_REPORTING=${ENABLE_COMPATIBILITY_REPORTING:-"OFF"} -DENABLE_COMPATIBILITY_LIST_DOWNLOAD=ON -DUSE_DISCORD_PRESENCE=ON -DENABLE_QT_TRANSLATION=ON -DCMAKE_INSTALL_PREFIX="/usr"

make -j$(nproc)

ccache -s

ctest -VV -C Release

make install DESTDIR=AppDir
rm -vf AppDir/usr/bin/yuzu-cmd AppDir/usr/bin/yuzu-tester

# Download tools needed to build an AppImage
wget -nc https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage
wget -nc https://github.com/linuxdeploy/linuxdeploy-plugin-qt/releases/download/continuous/linuxdeploy-plugin-qt-x86_64.AppImage
wget -nc https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
wget -nc https://github.com/darealshinji/AppImageKit-checkrt/releases/download/continuous/AppRun-patched-x86_64
wget -nc https://github.com/darealshinji/AppImageKit-checkrt/releases/download/continuous/exec-x86_64.so
# Set executable bit
chmod 755 \
    appimagetool-x86_64.AppImage \
    AppRun-patched-x86_64 \
    exec-x86_64.so \
    linuxdeploy-x86_64.AppImage \
    linuxdeploy-plugin-qt-x86_64.AppImage

# Workaround for https://github.com/AppImage/AppImageKit/issues/828
export APPIMAGE_EXTRACT_AND_RUN=1

mkdir -p AppDir/usr/optional
mkdir -p AppDir/usr/optional/libstdc++
mkdir -p AppDir/usr/optional/libgcc_s

# Deploy yuzu's needed dependencies
./linuxdeploy-x86_64.AppImage --appdir AppDir --plugin qt

# Workaround for building yuzu with GCC 10 but also trying to distribute it to Ubuntu 18.04 et al.
# See https://github.com/darealshinji/AppImageKit-checkrt
cp exec-x86_64.so AppDir/usr/optional/exec.so
cp AppRun-patched-x86_64 AppDir/AppRun
cp --dereference /usr/lib/x86_64-linux-gnu/libstdc++.so.6 AppDir/usr/optional/libstdc++/libstdc++.so.6
cp --dereference /lib/x86_64-linux-gnu/libgcc_s.so.1 AppDir/usr/optional/libgcc_s/libgcc_s.so.1

# Build the AppImage
./appimagetool-x86_64.AppImage AppDir
