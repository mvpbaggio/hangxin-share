include $(THEOS)/makefiles/common.mk

TWEAK_NAME = HangxinShare
HangxinShare_FILES = Tweak.xm
HangxinShare_CFLAGS = -fobjc-arc
HangxinShare_FRAMEWORKS = UIKit Foundation

include $(THEOS_MAKE_PATH)/tweak.mk
