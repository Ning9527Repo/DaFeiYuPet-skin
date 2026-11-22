#!/usr/bin/env python3
from pathlib import Path
import plistlib, json, re
from PIL import Image
r=Path(__file__).resolve().parents[1]
def text(p): return (r/p).read_text()
f=plistlib.loads((r/'MowangDaFeiYuPet.plist').read_bytes())
assert f['Filter']['Bundles']==['com.apple.springboard']
p=plistlib.loads((r/'MowangDaFeiYuPetPrefs/Resources/MowangDaFeiYuPetRoot.plist').read_bytes())
items={v['key']:v for v in p['items'] if 'key' in v}
assert items['enabled']['default'] is False and items['roam']['default'] is False
assert items['size']['default']==180 and items['opacity']['default']==1
assert items['scope']['default']==1
info=plistlib.loads((r/'MowangDaFeiYuPetPrefs/Resources/Info.plist').read_bytes())
assert info['CFBundleShortVersionString']=='0.1.1-skin1' and info['CFBundleVersion']=='0.1.1-skin1'
assert json.loads(text('tweak.json'))['minimum_ios']=='15.0'
assert '16.5:15.0' in text('MowangDaFeiYuPetBuild.mk')
s=text('Sources/MowangDaFeiYuPetController.m')
assert 'makeKeyAndVisible]' not in s and 'animationImages' not in s.replace('// At most one decode in flight + one displayed image, never UIImageView.animationImages.','')
assert '[self.mowang_dafeiyupet_link invalidate]' in s and 'generation!=' in s and 'if(!allow)' in s
assert 'return NO;' in text('Sources/MowangDaFeiYuPetConfig.m') or ' : NO;' in text('Sources/MowangDaFeiYuPetConfig.m')
assert '(mowang_dafeiyupet_homeOnly() && !mowang_dafeiyupet_homeVisible())' in s
assert 'if(mowang_dafeiyupet_homeOnly()) allow=allow && (self.mowang_dafeiyupet_chat!=nil || mowang_dafeiyupet_homeVisible());' in s
assert 'self.hidden || !pet || pet.hidden || mowang_dafeiyupet_locked()' in s
assert 'UIKeyboardWillShowNotification' in s and '!self.mowang_dafeiyupet_keyboardVisible' in s
assert 'initWithWindowScene:scene' in s
chat=text('MowangDaFeiYuPetPrefs/MowangDaFeiYuPetChatController.m')
for token in ('kSecAttrAccessibleWhenUnlockedThisDeviceOnly','ephemeralSessionConfiguration','65536','2048','completionHandler(nil)','invalidateAndCancel','90','95'):
    assert token in chat,token
for p in list((r/'Sources').glob('*'))+list((r/'MowangDaFeiYuPetPrefs').glob('*.m')):
    t=p.read_text()
    assert 'NSLog(' not in t, p
    for m in re.finditer(r'os_log\(([^,]+),', t):
        h=m.group(1).strip()
        assert h=='mowang_dafeiyupet_balanceLog()' or h.startswith('os_log_create("com.mowang.dafeiyupet"'), (p.name,h)
assets=r/'layout/Library/Application Support/MowangDaFeiYuPet'
manifest=plistlib.loads((assets/'manifest.plist').read_bytes()); count=0
assert set(manifest)=={'idle','look','tap','drag'}
for action,durations in manifest.items():
    assert len(durations)==120
    for i,duration in enumerate(durations):
        assert .08<=duration<=1
        im=Image.open(assets/action/f'{i:04d}.png')
        assert im.size==(220,124) and im.mode=='RGBA'
        assert im.getchannel('A').getextrema()==(0,255); count+=1
workflow=text('.github/workflows/build.yml')
assert 'workflow_dispatch:' in workflow and 'push:' not in workflow and 'release' not in workflow.lower()
assert 'https://github.com/roothide/theos.git' in workflow and 'https://github.com/theos/theos.git' in workflow
print(f'PASS contracts: config, injection, lifecycle, AI bounds, {count} true-alpha frames, manual-only CI')
