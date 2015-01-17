ARCHS = armv7 arm64
TARGET = iphone:clang:latest:latest

include theos/makefiles/common.mk

BUNDLE_NAME = Localizer
Localizer_FILES = Localizer.mm
Localizer_INSTALL_PATH = /Library/PreferenceBundles
Localizer_FRAMEWORKS = UIKit MessageUI
Localizer_PRIVATE_FRAMEWORKS = Preferences
Localizer_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/Localizer.plist$(ECHO_END)
