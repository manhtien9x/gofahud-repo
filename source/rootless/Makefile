export THEOS_PACKAGE_SCHEME = rootless
TARGET = iphone:clang:latest:15.0
ARCHS = arm64 arm64e
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = GOFADevProbe GofaLifecycle GofaLaunchHelper GofaPhoneOverlay GofaCarplayGlobal GofaCarplayOverlay
TOOL_NAME = gofahud-native-speed-bridge gofahud-test-speed

GOFADevProbe_FILES = probe/native-probe.m probe/notification-probe.m probe/swift-field-probe.m probe/publisher-probe.m probe/command-probe.m probe/location-audit.m probe/hud-message-probe.m common/speed-state.m common/hud-protocol.c common/hud-live-state.m
GOFADevProbe_CFLAGS = -fobjc-arc -O2 -UNDEBUG -Icommon -Wall -Wextra
GOFADevProbe_FRAMEWORKS = Foundation CoreFoundation UIKit QuartzCore CoreGraphics CoreLocation CoreBluetooth

GofaLifecycle_FILES = tweak/gofa-lifecycle.m
GofaLifecycle_CFLAGS = -fobjc-arc -O2 -UNDEBUG -Icommon -Wall -Wextra
GofaLifecycle_FRAMEWORKS = Foundation CoreFoundation UIKit QuartzCore CoreGraphics CoreLocation CoreBluetooth

GofaLaunchHelper_FILES = tweak/phone-launch-helper.m
GofaLaunchHelper_CFLAGS = -fobjc-arc -O2 -UNDEBUG -Icommon -Wall -Wextra
GofaLaunchHelper_FRAMEWORKS = Foundation CoreFoundation UIKit QuartzCore CoreGraphics CoreLocation CoreBluetooth

GofaPhoneOverlay_FILES = tweak/phone-overlay.m common/speed-state.m common/camera-state.m common/test-state.m common/speed-presentation.m common/phone-interaction.m common/hud-live-state.m
GofaPhoneOverlay_CFLAGS = -fobjc-arc -O2 -UNDEBUG -Icommon -Wall -Wextra
GofaPhoneOverlay_FRAMEWORKS = Foundation CoreFoundation UIKit QuartzCore CoreGraphics CoreLocation CoreBluetooth

GofaCarplayGlobal_FILES = tweak/carplay-global-overlay.m tweak/carplay-overlay.m common/speed-state.m common/hud-live-state.m common/speed-presentation.m
GofaCarplayGlobal_CFLAGS = -fobjc-arc -O2 -UNDEBUG -Icommon -Wall -Wextra
GofaCarplayGlobal_FRAMEWORKS = Foundation CoreFoundation UIKit QuartzCore CoreGraphics CoreLocation CoreBluetooth CarPlay

GofaCarplayOverlay_FILES = tweak/carplay-overlay.m common/speed-state.m common/hud-live-state.m common/speed-presentation.m
GofaCarplayOverlay_CFLAGS = -fobjc-arc -O2 -UNDEBUG -Icommon -Wall -Wextra
GofaCarplayOverlay_FRAMEWORKS = Foundation CoreFoundation UIKit QuartzCore CoreGraphics CoreLocation CoreBluetooth CarPlay

gofahud-native-speed-bridge_FILES = tweak/native-speed-bridge.m common/speed-state.m common/hud-live-state.m
gofahud-native-speed-bridge_CFLAGS = -fobjc-arc -O2 -UNDEBUG -Icommon -Wall -Wextra
gofahud-native-speed-bridge_FRAMEWORKS = Foundation CoreFoundation
gofahud-native-speed-bridge_INSTALL_PATH = /usr/libexec/gofahud-tests

gofahud-test-speed_FILES = tweak/test-speed.m common/test-state.m
gofahud-test-speed_CFLAGS = -fobjc-arc -O2 -UNDEBUG -Icommon -Wall -Wextra
gofahud-test-speed_FRAMEWORKS = Foundation CoreFoundation
gofahud-test-speed_INSTALL_PATH = /usr/libexec/gofahud-tests

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/tool.mk
