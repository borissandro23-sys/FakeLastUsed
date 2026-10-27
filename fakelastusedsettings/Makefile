BUNDLE_NAME := FakeLastUsedSettings

FakeLastUsedSettings_FILES := FLURootListController.m
FakeLastUsedSettings_FRAMEWORKS := UIKit
FakeLastUsedSettings_PRIVATE_FRAMEWORKS := Preferences
FakeLastUsedSettings_INSTALL_PATH := /Library/PreferenceBundles
FakeLastUsedSettings_CFLAGS := -fobjc-arc
FakeLastUsedSettings_RESOURCE_DIRS := Resources

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/FakeLastUsed.plist$(ECHO_END)
