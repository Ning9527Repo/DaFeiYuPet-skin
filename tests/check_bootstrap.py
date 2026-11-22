#!/usr/bin/env python3
"""Preprocess production path headers using the flags emitted by the shared Makefile."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
clang = shutil.which('clang')
assert clang, 'clang is required for production header preprocessing'
headers = ['ApelinBootstrap.h', 'MowangDaFeiYuPetPaths.h', 'MowangDaFeiYuPetMigration.h']
with tempfile.TemporaryDirectory() as directory:
    tmp = Path(directory)
    for framework in ['Foundation', 'Security']:
        folder = tmp / framework
        folder.mkdir()
        (folder / (framework + '.h')).write_text('/* Preprocessor-only framework stub. */\n')
    probe = tmp / 'probe.mk'
    probe.write_text('include ' + str(root / 'MowangDaFeiYuPetBuild.mk') + '\n'
                     '.PHONY: probe\nprobe:\n\t@printf "%s" "$(ADDITIONAL_CFLAGS)"\n')
    environment = dict(os.environ)
    for key in ['MAKEFLAGS', 'MFLAGS', 'ADDITIONAL_CFLAGS']:
        environment.pop(key, None)
    def preprocess(name, flags):
        return subprocess.check_output([clang, '-E', '-P', '-x', 'objective-c',
            '-I' + str(tmp), '-I' + str(root / 'Sources'), *flags,
            str(root / 'Sources' / name)], text=True, env=environment)
    for scheme in ['roothide', 'rootless']:
        flags = subprocess.check_output(['make', '-s', '-f', str(probe), 'probe',
            'THEOS_PACKAGE_SCHEME=' + scheme], text=True, env=environment).split()
        processed = {name: preprocess(name, flags) for name in headers}
        bootstrap = processed['ApelinBootstrap.h']
        if scheme == 'roothide':
            assert 'return @"/var/jb";' not in bootstrap
            assert '[parts[i] hasPrefix:@".jbroot-"]' in bootstrap
            assert 'return ApelinBootstrapPath(@"/var/mobile/Library/Preferences/com.mowang.dafeiyupet.plist");' in processed['MowangDaFeiYuPetPaths.h']
            assert 'return ApelinBootstrapPath(relative);' in processed['MowangDaFeiYuPetMigration.h']
        else:
            assert 'return @"/var/jb";' in bootstrap
            assert 'return @"/var/mobile/Library/Preferences/com.mowang.dafeiyupet.plist";' in processed['MowangDaFeiYuPetPaths.h']
            assert 'return relative;' in processed['MowangDaFeiYuPetMigration.h']
        print('PASS production path preprocessing:', scheme, 'resource + preferences + migration')
    old = preprocess('ApelinBootstrap.h', ['-DTHEOS_PACKAGE_SCHEME_ROOTHIDE=1'])
    assert 'return @"/var/jb";' in old, 'Old flags must reproduce the incorrect RootHide branch'
    print('PASS negative control: previous RootHide flags select /var/jb')
