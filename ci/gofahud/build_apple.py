import subprocess,pathlib
base=pathlib.Path(__file__).parent;out=base/'build';out.mkdir(exist_ok=True)
sdk=subprocess.check_output(['xcrun','--sdk','iphoneos','--show-sdk-path'],text=True).strip()
targets={'GofaHUDPrefs.dylib': ['prefs/controller.m', 'prefs/full-log-export.m', 'common/bubble-style.m', 'common/test-state.m'], 'GOFADevProbe.dylib': ['probe/native-probe.m', 'probe/notification-probe.m', 'probe/swift-field-probe.m', 'probe/publisher-probe.m', 'probe/command-probe.m', 'probe/location-audit.m', 'probe/hud-message-probe.m', 'common/speed-state.m', 'common/hud-protocol.c', 'common/hud-live-state.m'], 'GofaLifecycle.dylib': ['tweak/gofa-lifecycle.m'], 'GofaLaunchHelper.dylib': ['tweak/phone-launch-helper.m', 'tweak/background-supervisor.m'], 'GofaPhoneOverlay.dylib': ['tweak/phone-overlay.m', 'common/bubble-style.m', 'common/speed-state.m', 'common/camera-state.m', 'common/test-state.m', 'common/speed-presentation.m', 'common/phone-interaction.m', 'common/hud-live-state.m'], 'GofaCarplayGlobal.dylib': ['tweak/carplay-global-overlay.m', 'tweak/carplay-overlay.m', 'common/test-state.m', 'common/bubble-style.m', 'common/speed-state.m', 'common/hud-live-state.m', 'common/speed-presentation.m'], 'GofaCarplayOverlay.dylib': ['tweak/carplay-overlay.m', 'common/test-state.m', 'common/bubble-style.m', 'common/speed-state.m', 'common/hud-live-state.m', 'common/speed-presentation.m'], 'gofahud-native-speed-bridge': ['tweak/native-speed-bridge.m', 'common/speed-state.m', 'common/hud-live-state.m'], 'gofahud-test-speed': ['tweak/test-speed.m', 'common/test-state.m']}
for name,sources in targets.items():
 args=['xcrun','--sdk','iphoneos','clang','-target','arm64e-apple-ios15.0','-isysroot',sdk,'-fobjc-arc','-O2','-UNDEBUG','-I',str(base/'common')]
 args += [str(base/f) for f in sources]
 for fw in ['Foundation','CoreFoundation','UIKit','QuartzCore','CoreGraphics','CoreLocation','CoreBluetooth']+(['CarPlay'] if 'Carplay' in name else []): args+=['-framework',fw]
 args+=['-Wl,-undefined,dynamic_lookup']
 if name.endswith('.dylib'): args+=['-dynamiclib','-Wl,-install_name,/var/jb/Library/MobileSubstrate/DynamicLibraries/'+name]
 args+=['-o',str(out/name)]
 subprocess.run(args,check=True);subprocess.run(['codesign','--force','--sign','-',str(out/name)],check=True)
 print('BUILT',name,flush=True)
