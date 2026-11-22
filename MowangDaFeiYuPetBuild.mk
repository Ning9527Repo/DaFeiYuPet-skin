DEBUG ?= 0
FINALPACKAGE ?= 1
ARCHS ?= arm64 arm64e

# SDK pinned once, deployment floor shared by tweak and preferences.
TARGET = iphone:clang:16.5:15.0
ifeq ($(THEOS_PACKAGE_SCHEME),roothide)
# These headers select RootHide resource and preferences paths with the Apelin macro.
ADDITIONAL_CFLAGS += -DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1 -DAPELIN_BOOTSTRAP_ROOTHIDE=1
endif
