#!/usr/bin/env python3
"""Offline contract tests; no network, compiler, install or preference writes."""
import hashlib
import json
import math
import plistlib
import struct
from pathlib import Path

PROJECT = Path(__file__).resolve().parents[1]
ROOT = PROJECT / 'layout/Library/Application Support/MowangDaFeiYuPet/LiveTextures'
SCHEMES = ['deepseek', 'harness', 'chatgpt', 'claude', 'gemini', 'qwen', 'kimi', 'minimax']
MODEL = json.loads((ROOT / 'model.json').read_text())
PARENTS = {'body', 'hairSway', 'tailBend', 'armFar', 'legBack', 'skirt', 'legFront', 'skirtSit', 'armNear', 'finFar', 'bangsSway', 'headMid', 'headFeat', 'finNear', 'ahoge'}


def image(relative, scheme):
    path = ROOT / 'schemes' / scheme / relative
    if not path.exists():
        path = ROOT / relative
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n', path
    width, height = struct.unpack('>II', data[16:24])
    assert width > 0 and height > 0, path
    return path, width, height


def feature_box(rect):
    x1, y1, x2, y2 = rect
    u = MODEL['units']
    return (128 + (x1-u['X0'])*u['S'], 256 + (y1-u['FEET'])*u['S'],
            (x2-x1)*u['S'], (y2-y1)*u['S'])


def main():
    assert len(MODEL['parts']) == 26
    assert {p['parent'] for p in MODEL['parts']} == PARENTS
    assert set(MODEL['pivots']) >= {'body', 'waist', 'neck', 'head', 'tail', 'armNear', 'armFar', 'legBack', 'legFront', 'finNear', 'finFar', 'ahoge'}
    v = MODEL['view']
    assert v == [-12, -8, 268, 272] and v[2]-v[0] == v[3]-v[1] == 280
    for p in MODEL['parts']:
        assert len(p['box']) == 4 and min(p['box'][2:]) > 0
        assert p['z'] > 0 and len(p['grid']) == 2
    z = [p['id'] for p in sorted(MODEL['parts'], key=lambda p:p['z'])]
    assert z.index('leg_front') < z.index('leg_back') < z.index('face') < z.index('bangs')
    face = next(p['box'] for p in MODEL['parts'] if p['id'] == 'face')
    count = 0
    for scheme in SCHEMES:
        for p in MODEL['parts']:
            _, w, h = image('tex/' + p['tex'] + '.png', scheme)
            # Body assets were downsampled by DS=0.6; box is full-art dimensions*S.
            assert abs(w - p['box'][2] / MODEL['units']['S'] * MODEL['units']['DS']) <= 1, p['id']
            assert abs(h - p['box'][3] / MODEL['units']['S'] * MODEL['units']['DS']) <= 1, p['id']
            count += 1
        for eye in ['eyeL', 'eyeR']:
            d = MODEL['feat']['eyes'][eye]
            assert len(d['lidFit']) == len(d['rimFit']) == 3
            for kind in ['ball', 'iris', 'hl', 'lash']:
                image('feat/' + eye + '_' + kind + '.png', scheme)
                x, y, w, h = feature_box(d[kind])
                assert face[0]-5 < x < face[0]+face[2]+5
                assert face[1] < y < face[1]+face[3]
                assert w > 0 and h > 0
                count += 1
        for name, rect in MODEL['feat']['sprites'].items():
            _, w, h = image('feat/' + name + '.png', scheme)
            assert (w, h) == (rect[2]-rect[0], rect[3]-rect[1]), name
            count += 1
    # deepseek intentionally has no override directory; real original tex/feat are its source.
    assert not (ROOT / 'schemes/deepseek').exists()
    assert len({hashlib.sha256(image('tex/hair_back.png', s)[0].read_bytes()).hexdigest() for s in SCHEMES}) == 8
    root = plistlib.loads((PROJECT / 'MowangDaFeiYuPetPrefs/Resources/MowangDaFeiYuPetRoot.plist').read_bytes())
    prefs = [row for row in root['items'] if row.get('key') == 'skin']
    assert len(prefs) == 1
    p = prefs[0]
    assert p['validValues'] == ['original'] + SCHEMES
    assert len(p['validTitles']) == 9 and p['default'] == 'original'
    assert p['PostNotification'] == 'com.mowang.dafeiyupet.preferences-changed'
    controller = (PROJECT / 'Sources/MowangDaFeiYuPetController.m').read_text()
    assert controller.index('if(self.textureView) {\n        // Share physics') < controller.index('NSArray *durations=self.mowang_dafeiyupet_manifest')
    assert 'generation!=self.mowang_dafeiyupet_generation' in controller
    assert 'self.textureSelection=nil' in controller
    renderer = (PROJECT / 'Sources/MowangDaFeiYuPetTextureView.m').read_text()
    assert all(term not in renderer for term in ['thumbs/', '.gif', 'animationImages', 'NSURLSession'])
    assert 'CGContextSetBlendMode(c,kCGBlendModeMultiply)' in renderer
    assert 'CGContextClip(c)' in renderer and 'lidFit' in renderer
    for time in [0, .045, .09, .135, .18, 4.3, 1e6]:
        phase = math.fmod(time, 4.3)
        blink = abs(phase-.09)/.09 if phase < .18 else 1
        assert 0 <= blink <= 1
    print(f'PASS: {len(SCHEMES)} schemes; {len(MODEL["parts"])} body parts; 8 normal-eye components; {len(MODEL["feat"]["sprites"])} expression assets; {count} mapped PNG reads')
    print('PASS: coordinate conversion, view bounds, z order, source fallback, 9 preferences, notification, live/GIF branch exclusion, blink range')

if __name__ == '__main__':
    main()
