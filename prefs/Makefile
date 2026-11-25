TARGET := iphone:clang:latest:15.0
ARCHS := arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = ZUSPrefs
ZUSPrefs_FILES = ZUSRootListController.m
ZUSPrefs_INSTALL_PATH = /Library/PreferenceBundles
ZUSPrefs_FRAMEWORKS = UIKit
ZUSPrefs_CFLAGS = -fobjc-arc
ZUSPrefs_LDFLAGS = -undefined dynamic_lookup

include $(THEOS_MAKE_PATH)/bundle.mk
