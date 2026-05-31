# ============================================================
# Makefile — HelloWorldATV.frappliance
# ============================================================

export DEBUG      = 0
export SDKVERSION = 4.3
export TARGET     = iphone

target = iphone:4.3:7.0

ARCHS = armv7

include $(THEOS)/makefiles/common.mk
include $(THEOS)/makefiles/aggregate.mk

BUNDLE_NAME = HelloWorldATV

HelloWorldATV_FILES  = Classes/HelloWorldAppliance.mm
HelloWorldATV_FILES += Classes/HelloWorldController.mm

HelloWorldATV_INSTALL_PATH     = /Applications/AppleTV.app/Appliances
HelloWorldATV_BUNDLE_EXTENSION = frappliance

HelloWorldATV_CFLAGS  = -isysroot $(THEOS)/sdks/iPhoneOS$(SDKVERSION).sdk
HelloWorldATV_CFLAGS += \
  -F$(THEOS)/sdks/iPhoneOS$(SDKVERSION).sdk/System/Library/PrivateFrameworks
HelloWorldATV_CFLAGS += -I$(THEOS)/include
HelloWorldATV_CFLAGS += -Wno-deprecated-declarations
HelloWorldATV_CFLAGS += -Wno-objc-method-access

HelloWorldATV_LDFLAGS  = -all_load
HelloWorldATV_LDFLAGS += -undefined dynamic_lookup
# libc++ は iOS 4.3 SDK に存在しない。
# theos が clang++ でリンクするため -lc++ を要求するが、
# Objective-C のみのコードなので C++ ランタイムは不要。
# -nodefaultlibs で自動リンクを無効にし、必要なものだけ明示する。
HelloWorldATV_LDFLAGS += -nodefaultlibs
HelloWorldATV_LDFLAGS += -lobjc
HelloWorldATV_LDFLAGS += -lSystem
HelloWorldATV_LDFLAGS += -framework UIKit
HelloWorldATV_LDFLAGS += -framework Foundation
HelloWorldATV_LDFLAGS += -framework CoreGraphics
HelloWorldATV_LDFLAGS += -lsubstrate

include $(FW_MAKEDIR)/bundle.mk

after-install::
	install.exec "killall -9 AppleTV"
