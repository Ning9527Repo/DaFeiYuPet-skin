#!/usr/bin/env python3
"""Strict deb + Mach-O slices + code-signature + actual packaged alpha audit."""
from pathlib import Path
import subprocess, tempfile, sys, struct, plistlib, hashlib, json
from PIL import Image
from signature_integrity import mowang_dafeiyupet_verify_signature
package=Path(sys.argv[1]).resolve(); scheme=sys.argv[2]
def run(*args): return subprocess.check_output(args,text=True).strip()
meta=run('dpkg-deb','-f',str(package)); print(meta)
expected='iphoneos-arm64e' if scheme=='roothide' else 'iphoneos-arm64'
control=(Path(__file__).resolve().parents[1]/'control').read_text()
version=next(line.split(':',1)[1].strip() for line in control.splitlines() if line.startswith('Version:'))
assert f'Architecture: {expected}' in meta and f'Version: {version}\n' in meta+'\n'
assert 'Package: com.mowang.dafeiyupet' in meta

def slices(path):
    data=path.read_bytes(); magic=struct.unpack_from('>I',data)[0]
    if magic==0xcafebabe:
        n=struct.unpack_from('>I',data,4)[0]
        regions=[struct.unpack_from('>IIIII',data,8+20*i)[2:4] for i in range(n)]
    else: regions=[(0,len(data))]
    result=[]
    for offset,length in regions:
        h=struct.unpack_from('<IIIIIIII',data,offset)
        image=data[offset:offset+length]
        if scheme=='roothide':
            assert b'.jbroot-' in image,('Missing dynamic RootHide resource root',path)
            assert b'/var/jb\x00' not in image,('Fixed rootless path in RootHide image',path)
        else:
            assert b'/var/jb\x00' in image,('Missing rootless resource root',path)
        if (h[2]&0xffffff)==2:
            assert h[2]==0x80000002,('Missing real arm64e ptrauth ABI',hex(h[2]))
        assert h[0]==0xfeedfacf
        cpu,subtype,ncmds=h[1],h[2]&0xffffff,h[4]
        pos=offset+32; signed=False; deployment=False; loads=[]
        for _ in range(ncmds):
            cmd,size=struct.unpack_from('<II',data,pos); assert size>=8
            if cmd==0x32:
                platform,minos,sdk=struct.unpack_from('<III',data,pos+8)
                assert platform==2 and minos==0x000f0000,('Expected iOS 15.0 minimum',platform,hex(minos))
                print('LC_BUILD_VERSION min=15.0 SDK=%d.%d.%d'%((sdk>>16)&65535,(sdk>>8)&255,sdk&255))
                deployment=True
            if cmd in (0xc,0x80000018,0x8000001f,0x20,0x80000023):
                rel=struct.unpack_from('<I',data,pos+8)[0]
                loads.append(data[pos+rel:pos+size].split(b'\0')[0].decode())
            if cmd==0xd:
                rel=struct.unpack_from('<I',data,pos+8)[0]
                print('LC_ID_DYLIB (image identity)',data[pos+rel:pos+size].split(b'\0')[0].decode())
            if cmd==0x1d:
                blob,size2=struct.unpack_from('<II',data,pos+8)
                assert size2>0 and offset+blob+size2<=len(data)
                assert struct.unpack_from('>I',data,offset+blob)[0]==0xfade0cc0
                info=path.parent/'Info.plist'
                info_bytes=info.read_bytes() if info.exists() else None
                print('Verified ldid CodeDirectories',mowang_dafeiyupet_verify_signature(data,offset,blob,size2,info_bytes))
                tampered=bytearray(data); tampered[offset+256]^=1
                try:
                    mowang_dafeiyupet_verify_signature(tampered,offset,blob,size2,info_bytes)
                except AssertionError: pass
                else: raise AssertionError('Signature verification failed to reject altered code')
                signed=True
            pos+=size
        assert signed,'Missing LC_CODE_SIGNATURE or embedded signature'
        assert deployment,'Missing iOS LC_BUILD_VERSION'
        if path.suffix=='.dylib':
            if scheme=='roothide': assert '@loader_path/.jbroot/usr/lib/libsubstrate.dylib' in loads
            else: assert '/var/jb/usr/lib/libsubstrate.dylib' in loads
        print('Loader paths',loads)
        result.append((cpu,subtype))
    expected_slices={(0x100000c,2)} if scheme=='roothide' else {(0x100000c,0),(0x100000c,2)}
    ok = set(result)==expected_slices or (scheme=='roothide' and set(result)=={(0x100000c,0),(0x100000c,2)})
    assert ok,('Unexpected Mach-O slices',result,expected_slices)
    return result
with tempfile.TemporaryDirectory() as t:
    root=Path(t); subprocess.run(['dpkg-deb','-x',str(package),t],check=True)
    dylibs=list(root.rglob('MowangDaFeiYuPet.dylib')); assert len(dylibs)==1
    binaries=[dylibs[0],*root.rglob('MowangDaFeiYuPetPrefs.bundle/MowangDaFeiYuPetPrefs')]
    assert len(binaries)==2
    for b in binaries:
        print(b.relative_to(root),slices(b))
    plists=list(root.rglob('DynamicLibraries/MowangDaFeiYuPet.plist')); assert len(plists)==1
    assert plistlib.loads(plists[0].read_bytes())['Filter']['Bundles']==['com.apple.springboard']
    manifests=list(root.rglob('MowangDaFeiYuPet/manifest.plist')); assert len(manifests)==1
    manifest=plistlib.loads(manifests[0].read_bytes()); count=0
    for action,durations in manifest.items():
        for i in range(len(durations)):
            im=Image.open(manifests[0].parent/action/f'{i:04d}.png')
            assert im.size==(220,124) and im.getchannel('A').getextrema()==(0,255); count+=1
    assert count==480
    # Audit the package payload, not merely the source tree.
    source=Path(__file__).resolve().parents[1]
    live_source=source/'layout/Library/Application Support/MowangDaFeiYuPet/LiveTextures'
    live=manifests[0].parent/'LiveTextures'
    assert live.is_dir()
    expected_files={p.relative_to(live_source) for p in live_source.rglob('*') if p.is_file()}
    actual_files={p.relative_to(live) for p in live.rglob('*') if p.is_file()}
    assert actual_files==expected_files,('LiveTextures file list mismatch',len(actual_files),len(expected_files))
    assert sum(p.suffix=='.png' for p in actual_files)==443
    for rel in expected_files:
        assert hashlib.sha256((live/rel).read_bytes()).digest()==hashlib.sha256((live_source/rel).read_bytes()).digest(),rel
    roots=list(root.rglob('MowangDaFeiYuPetRoot.plist')); assert len(roots)==1
    rows=plistlib.loads(roots[0].read_bytes())['items']
    skin=[row for row in rows if row.get('key')=='skin']; assert len(skin)==1
    assert skin[0]['validValues']==['original','deepseek','harness','chatgpt','claude','gemini','qwen','kimi','minimax']
    assert len(skin[0]['validTitles'])==9 and skin[0]['default']=='original'
    assert skin[0]['PostNotification']=='com.mowang.dafeiyupet.preferences-changed'
    # Theos may rewrite XML as binary plist; compare the entire decoded object.
    assert plistlib.loads(roots[0].read_bytes())==plistlib.loads((source/'MowangDaFeiYuPetPrefs/Resources/MowangDaFeiYuPetRoot.plist').read_bytes())
    image=dylibs[0].read_bytes()
    for symbol in [b'MowangDaFeiYuPetTextureView',b'MWTexturePiece',b'drawRect:',b'LiveTextures',b'model.json']:
        assert symbol in image,('Missing native renderer marker',symbol)
    for symbol in [b'MWPetDoubaoVoice', b'X-Api-Key', b'seed-tts-2.0', b'ICL_uranus_zh_female_jiaoruoluoli_tob', b'zh_female_lingling_uranus_bigtts']:
        assert symbol in image, ('Missing Doubao voice marker', symbol)
    print('PASS native Doubao client, TTS2.0 headers and voice identifiers')
    print('PASS live payload: 443 byte-identical PNGs, all metadata, original + 8 skin choices, native renderer symbols')
    assert list(root.rglob('ARTWORK-NONCOMMERCIAL.md'))
    assert list(root.rglob('PreferenceLoader/Preferences/MowangDaFeiYuPetPrefs.plist'))
    # Rootless package physically owns /var/jb; RootHide uses its relocation-aware toolchain.
    if scheme=='rootless': assert str(dylibs[0].relative_to(root)).startswith('var/jb/')
    print('PASS package:',scheme,'480 alpha frames, preference entry, licenses, signed expected slices')
print('SHA256',hashlib.sha256(package.read_bytes()).hexdigest())
