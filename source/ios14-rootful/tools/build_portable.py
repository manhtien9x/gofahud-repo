import os,pathlib,subprocess,sys
base=pathlib.Path(__file__).resolve().parents[1]
sdk=pathlib.Path(os.environ['GOFA_SDK'])
zig=os.environ['GOFA_ZIG']; linker=os.environ['GOFA_LLD']
targets={'GofaHUDPrefs.dylib':['prefs/controller.m','prefs/full-log-export.m','common/bubble-style.m','common/test-state.m'],'GOFADevProbe.dylib': ['probe/native-probe.m', 'probe/notification-probe.m', 'probe/command-probe.m', 'probe/location-audit.m', 'probe/hud-message-probe.m', 'common/speed-state.m', 'common/hud-protocol.c', 'common/hud-live-state.m'], 'GofaLifecycle.dylib': ['tweak/gofa-lifecycle.m'], 'GofaLaunchHelper.dylib': ['tweak/phone-launch-helper.m','tweak/background-supervisor.m'], 'GofaPhoneOverlay.dylib': ['tweak/phone-overlay.m','common/bubble-style.m', 'common/speed-state.m', 'common/camera-state.m', 'common/test-state.m', 'common/speed-presentation.m', 'common/phone-interaction.m', 'common/hud-live-state.m'], 'GofaCarplayGlobal.dylib': ['tweak/carplay-global-overlay.m', 'tweak/carplay-overlay.m','common/test-state.m','common/bubble-style.m', 'common/speed-state.m', 'common/hud-live-state.m', 'common/speed-presentation.m'], 'GofaCarplayOverlay.dylib': ['tweak/carplay-overlay.m','common/test-state.m','common/bubble-style.m', 'common/speed-state.m', 'common/hud-live-state.m', 'common/speed-presentation.m'], 'gofahud-native-speed-bridge': ['tweak/native-speed-bridge.m', 'common/speed-state.m', 'common/hud-live-state.m'], 'gofahud-test-speed': ['tweak/test-speed.m', 'common/test-state.m']}
targets['gofahud-export-self-test']=['tests/full-log-export-main.m','prefs/full-log-export.m']
output=base/'build'; output.mkdir(exist_ok=True)
for name,files in targets.items():
    if len(sys.argv)>1 and name not in sys.argv[1:]: continue
    objects=[]
    for i,file in enumerate(files):
        obj=output/(name+'.'+str(i)+'.o')
        args=[zig,'cc','-target','aarch64-ios.14.0','-isysroot',str(sdk),'-isystem',str(sdk/'usr/include'),'-iframework',str(sdk/'System/Library/Frameworks'),'-fobjc-arc','-O2','-UNDEBUG','-fno-sanitize=all','-Wno-macro-redefined','-I',str(base/'common'),'-c',str(base/file),'-o',str(obj)]
        subprocess.run(args,check=True); objects.append(str(obj))
    args=[linker,'-flavor','darwin','-arch','arm64','-platform_version','ios','14.0','15.6','-syslibroot',str(sdk)]
    for framework in ['Foundation','CoreFoundation','UIKit','QuartzCore','CoreGraphics','CoreLocation','CoreBluetooth']+(['CarPlay'] if 'Carplay' in name else []): args+=['-framework',framework]
    args+=['-lobjc','-lSystem','-adhoc_codesign','-undefined','dynamic_lookup']
    if name.endswith('.dylib'): args+=['-dylib','-install_name','/Library/MobileSubstrate/DynamicLibraries/'+name]
    subprocess.run(args+objects+['-o',str(output/name)],check=True)
    print('Built',name)
