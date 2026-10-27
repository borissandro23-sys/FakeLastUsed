TARGET := iphone:clang:15.5:15.0
ARCHS := arm64
INSTALL_TARGET_PROCESSES := Preferences

THEOS_PACKAGE_SCHEME := rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME := FakeLastUsed

FakeLastUsed_FILES := Tweak.x Sources/FLUPreferences.m
FakeLastUsed_CFLAGS := -fobjc-arc -Wno-deprecated-declarations
FakeLastUsed_FRAMEWORKS := UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += fakelastusedsettings
include $(THEOS_MAKE_PATH)/aggregate.mk

after-install::
	install.exec "killall -9 Preferences 2>/dev/null || true"
