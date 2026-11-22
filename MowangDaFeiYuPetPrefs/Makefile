include ../MowangDaFeiYuPetBuild.mk
include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = MowangDaFeiYuPetPrefs
MowangDaFeiYuPetPrefs_FILES = $(wildcard *.m)
MowangDaFeiYuPetPrefs_CFLAGS = -fobjc-arc -I../Sources
MowangDaFeiYuPetPrefs_FRAMEWORKS = UIKit Foundation CoreFoundation Security
MowangDaFeiYuPetPrefs_PRIVATE_FRAMEWORKS = Preferences
MowangDaFeiYuPetPrefs_INSTALL_PATH = /Library/PreferenceBundles

include $(THEOS_MAKE_PATH)/bundle.mk
