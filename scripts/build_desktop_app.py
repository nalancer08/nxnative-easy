#!/usr/bin/env python3
"""Build a local native launcher without Apple signing or game resources."""
import argparse
from pathlib import Path
import plistlib
import subprocess
import tempfile
import shutil
import json
import os
import uuid

REPO=Path(__file__).resolve().parents[1]

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,required=True,help='app path outside the source repository')
    parser.add_argument('--open',action='store_true')
    parser.add_argument('--portable',action='store_true',help='include source and relocatable build tools for a distributable app')
    args=parser.parse_args()
    output=args.output.expanduser().resolve()
    if output==REPO or REPO in output.parents:parser.error('Keep build outputs outside the repository.')
    if output.suffix!='.app':parser.error('Output must end with .app')
    output.parent.mkdir(parents=True,exist_ok=True)
    # Compile beside the destination. A compiler/signing failure must preserve the installed app.
    with tempfile.TemporaryDirectory(prefix='.nxnative-build-',dir=output.parent) as temporary:
        staged=Path(temporary)/output.name
        build_bundle(staged,portable=args.portable)
        subprocess.run(['codesign','--verify','--deep','--strict',str(staged)],check=True)
        install_bundle(staged,output)
    if args.open:subprocess.run(['open',str(output)],check=True)
    print(output)

def install_bundle(staged,output):
    if not output.exists():
        os.replace(staged,output)
        return
    info=plistlib.loads((output/'Contents/Info.plist').read_bytes())
    if info.get('CFBundleIdentifier')!='com.nalancer08.nxnative.easy':
        raise ValueError('The destination contains another app; it was preserved.')
    backup=output.with_name('.'+output.name+'.previous-'+uuid.uuid4().hex[:10])
    os.replace(output,backup)
    try:
        os.replace(staged,output)
    except BaseException:
        os.replace(backup,output)
        raise


def build_bundle(output,portable=False):
    contents=output/'Contents';macos=contents/'MacOS';macos.mkdir(parents=True,exist_ok=True)
    subprocess.run(['xcrun','swiftc','-parse-as-library','-swift-version','5','-target','arm64-apple-macosx26.0',
        *(str(p) for p in sorted((REPO/'desktop/NxNativeEasy').glob('*.swift'))),'-o',str(macos/'NxNativeEasy'),
        '-framework','SwiftUI','-framework','AppKit','-framework','GameController'],check=True)
    # The optional worker shares all identity/policy code, but has no UI entry point.
    with tempfile.TemporaryDirectory(prefix='nxnative-worker-') as temporary:
        model=Path(temporary)/'MainModel.swift'
        model.write_text((REPO/'desktop/NxNativeEasy/main.swift').read_text().split('@main struct NxNativeEasyApp: App {')[0])
        entry=Path(temporary)/'RefreshMain.swift'
        entry.write_text('import AppKit\n@main struct RefreshMain { @MainActor static func main() { NSApplication.shared.setActivationPolicy(.prohibited); BackgroundRenewal.run() } }\n')
        sources=[str(p) for p in sorted((REPO/'desktop/NxNativeEasy').glob('*.swift')) if p.name!='main.swift']
        subprocess.run(['xcrun','swiftc','-parse-as-library','-swift-version','5','-target','arm64-apple-macosx26.0',str(model),*sources,str(entry),'-o',str(macos/'nxnative-refresh'),'-framework','SwiftUI','-framework','AppKit','-framework','GameController'],check=True)
    agents=contents/'Library/LaunchAgents';agents.mkdir(parents=True)
    (agents/'com.nalancer08.nxnative.refresh.plist').write_bytes(plistlib.dumps(dict(Label='com.nalancer08.nxnative.refresh',BundleProgram='Contents/MacOS/nxnative-refresh',StartInterval=1800,RunAtLoad=True,ProcessType='Background')))
    resources=contents/'Resources';resources.mkdir(exist_ok=True)
    from build_sideload_helper import build as build_helper
    helper_cache=Path(os.environ.get('NXE_SIDELOAD_BUILD_CACHE',str(REPO.parent/'nxnative-sideload-tools')))
    build_helper(macos/'nxnative-sideload',helper_cache)
    shutil.move(str(macos/'sideload-licenses'),str(resources/'SideloadLicenses'))
    shutil.copy2(REPO/'desktop/NxNativeEasy/Assets/AppIcon.png',resources/'BrandIcon.png')
    with tempfile.TemporaryDirectory(prefix='nxnative-icon-') as temporary:
        iconset=Path(temporary)/'AppIcon.iconset';iconset.mkdir()
        subprocess.run(['xcrun','swift',str(REPO/'desktop/NxNativeEasy/Assets/draw_icon.swift'),str(iconset)],check=True)
        subprocess.run(['iconutil','-c','icns',str(iconset),'-o',str(resources/'AppIcon.icns')],check=True)
    shutil.copy2(REPO/'desktop/NxNativeEasy/update_app.py',resources/'update_app.py')
    if portable:
        from bundle_tools import bundle
        cached=os.environ.get('NXE_PORTABLE_TOOLS')
        if cached:shutil.copytree(Path(cached),resources/'Tools',symlinks=True)
        bundle(resources/'Tools',REPO.parent/'portable-tools-cache')
        source=resources/'Source';source.mkdir()
        archive=resources/'source.tar'
        subprocess.run(['git','-C',str(REPO),'archive','HEAD','-o',str(archive)],check=True)
        import tarfile
        with tarfile.open(archive) as packed:packed.extractall(source,filter='data')
        archive.unlink()
        revision=subprocess.check_output(['git','-C',str(REPO),'rev-parse','HEAD'],text=True).strip()
        (source/'SOURCE_REVISION').write_text(revision+'\n')
        import hashlib
        index={str(p.relative_to(source)):hashlib.sha256(p.read_bytes()).hexdigest() for p in source.rglob('*') if p.is_file() and not p.is_symlink()}
        (source/'SOURCE_INDEX.json').write_text(json.dumps(index,sort_keys=True)+'\n')
        # Nested portable Mach-O resources must be sealed before the outer bundle.
        magic={b'\xcf\xfa\xed\xfe',b'\xce\xfa\xed\xfe',b'\xca\xfe\xba\xbe',b'\xbe\xba\xfe\xca'}
        for binary in (resources/'Tools').rglob('*'):
            if binary.is_file() and not binary.is_symlink():
                with binary.open('rb') as stream:is_macho=stream.read(4) in magic
                if is_macho:subprocess.run(['codesign','--force','--sign','-','--timestamp=none',str(binary)],check=True,capture_output=True)
    release=json.loads((REPO/'desktop/release.json').read_text())
    revision=subprocess.run(['git','-C',str(REPO),'rev-parse','HEAD'],capture_output=True,text=True).stdout.strip()
    if not revision and (REPO/'SOURCE_REVISION').is_file():revision=(REPO/'SOURCE_REVISION').read_text().strip()
    info=dict(NxNativeSourceRevision=revision, CFBundleIconFile='AppIcon', CFBundleIdentifier='com.nalancer08.nxnative.easy',CFBundleName='nxnative Easy',
              CFBundleDisplayName='nxnative Easy',CFBundleExecutable='NxNativeEasy',
              CFBundlePackageType='APPL',CFBundleShortVersionString=release['version'],CFBundleVersion=str(release['build']),
              LSMinimumSystemVersion='26.0',CFBundleDevelopmentRegion='en',CFBundleLocalizations=['en','es'],NSHighResolutionCapable=True,NxNativeSource='' if portable else str(REPO))
    (contents/'Info.plist').write_bytes(plistlib.dumps(info))
    subprocess.run([str(macos/'nxnative-refresh'),'--dry-run'],check=True,capture_output=True,timeout=15)
    # Explicit ad-hoc signing: '-' never selects an Apple certificate or team.
    subprocess.run(['codesign','--force','--sign','-','--timestamp=none',str(macos/'nxnative-refresh')],check=True)
    subprocess.run(['codesign','--force','--sign','-','--timestamp=none',str(output)],check=True)

if __name__=='__main__':main()
