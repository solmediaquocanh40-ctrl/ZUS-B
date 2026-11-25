TARGET := iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ZUS
ZUS_FILES = Tweak.x
ZUS_FRAMEWORKS = UIKit Foundation LocalAuthentication Photos Security
ZUS_LIBRARIES = substrate sqlite3
ZUS_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
