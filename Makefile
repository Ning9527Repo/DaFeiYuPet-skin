DEBUG = 0
FINALPACKAGE = 1

ARCHS = arm64 arm64e

# Share the SDK and deployment targets with the PreferenceBundle.
include MowangDaFeiYuPetBuild.mk
include $(THEOS)/makefiles/common.mk

TWEAK_NAME = MowangDaFeiYuPet
MowangDaFeiYuPet_FILES = $(wildcard Hooks/*.xm Sources/*.m) MowangDaFeiYuPetPrefs/MowangDaFeiYuPetChatController.m
MowangDaFeiYuPet_CFLAGS = -fobjc-arc -I./Headers -I./Sources -IMowangDaFeiYuPetPrefs
MowangDaFeiYuPet_FRAMEWORKS = UIKit Foundation CoreFoundation QuartzCore LocalAuthentication AVFoundation
MowangDaFeiYuPet_LIBRARIES = substrate

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += MowangDaFeiYuPetPrefs
include $(THEOS_MAKE_PATH)/aggregate.mk
