#!/bin/sh
set -eu
: "${APELIN_PACKAGE_DIR:?}" "${APELIN_PROJECT_ROOT:?}" "${APELIN_BOOTSTRAP:?}" "${APELIN_ARCHITECTURE:?}" "${APELIN_BUILD_ID:?}" "${TMPDIR:?}"
: "${APELIN_PREFIX?}"
stage="$(mktemp -d "${TMPDIR:?}/dafeiyu.XXXXXX")"
trap 'rm -rf -- "${stage:?}"' EXIT
mkdir -p build/support
cp -R /usr/share/apelin/development/wiki.qaq.apelin.dev.tweak/support/. build/support/
cp -R /usr/share/apelin/development/wiki.qaq.apelin.dev.preferences/support/. build/support/
case "$APELIN_BOOTSTRAP" in
 roothide) arches=arm64e; define=APELIN_BOOTSTRAP_ROOTHIDE ;;
 rootless) arches='arm64 arm64e'; define=APELIN_BOOTSTRAP_ROOTLESS ;;
 *) exit 2 ;;
esac
for arch in $arches; do
 clang -arch "$arch" -miphoneos-version-min=16.0 -fobjc-arc -fvisibility=hidden -O2 -g -dynamiclib -IHeaders -ISources -Ibuild/support/include -D"$define"=1 -DAPELIN_BUILD_ID="\"$APELIN_BUILD_ID\"" Hooks/MowangDaFeiYuPetMain.m Sources/MowangDaFeiYuPetController.m Sources/MowangDaFeiYuPetConfig.m Sources/MowangDaFeiYuPetTextureView.m Sources/MWPetDoubaoVoice.m Sources/MowangDaFeiYuPetLyricNet.m Sources/MWPetLiveActions.m Sources/MWPetActionProps.m MowangDaFeiYuPetPrefs/MowangDaFeiYuPetChatController.m -framework Security -framework AVFoundation -L"build/support/lib/$APELIN_BOOTSTRAP" -lsubstrate -framework UIKit -framework Foundation -framework CoreFoundation -framework CoreGraphics -framework QuartzCore -framework ImageIO -o "build/pet-$arch.dylib"
 clang -arch "$arch" -miphoneos-version-min=16.0 -fobjc-arc -O2 -g -bundle -IHeaders -ISources -Ibuild/support/include -D"$define"=1 MowangDaFeiYuPetPrefs/*.m Sources/MWPetDoubaoVoice.m -Fbuild/support/stubs -framework Preferences -framework UIKit -framework Foundation -framework CoreFoundation -framework CoreGraphics -framework Security -framework AVFoundation -o "build/prefs-$arch"
done
if [ "$APELIN_BOOTSTRAP" = rootless ]; then
 lipo -create build/pet-arm64.dylib build/pet-arm64e.dylib -output build/MowangDaFeiYuPet.dylib
 lipo -create build/prefs-arm64 build/prefs-arm64e -output build/MowangDaFeiYuPetPrefs
else
 cp build/pet-arm64e.dylib build/MowangDaFeiYuPet.dylib
 cp build/prefs-arm64e build/MowangDaFeiYuPetPrefs
fi
ldid -S build/MowangDaFeiYuPet.dylib
ldid -S build/MowangDaFeiYuPetPrefs
mkdir -p "${stage:?}${APELIN_PREFIX}/Library/MobileSubstrate/DynamicLibraries" "${stage:?}${APELIN_PREFIX}/Library/PreferenceBundles/MowangDaFeiYuPetPrefs.bundle" "${stage:?}/DEBIAN"
cp -R layout/. "${stage:?}${APELIN_PREFIX}/"
cp build/MowangDaFeiYuPet.dylib MowangDaFeiYuPet.plist "${stage:?}${APELIN_PREFIX}/Library/MobileSubstrate/DynamicLibraries/"
cp -R MowangDaFeiYuPetPrefs/Resources/. "${stage:?}${APELIN_PREFIX}/Library/PreferenceBundles/MowangDaFeiYuPetPrefs.bundle/"
cp build/MowangDaFeiYuPetPrefs "${stage:?}${APELIN_PREFIX}/Library/PreferenceBundles/MowangDaFeiYuPetPrefs.bundle/"
sed "s/^Architecture:.*/Architecture: $APELIN_ARCHITECTURE/" control > "${stage:?}/DEBIAN/control"
dpkg-deb -b --root-owner-group "$stage" "${APELIN_PACKAGE_DIR:?}/"
